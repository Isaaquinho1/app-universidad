import 'dart:async';
import 'dart:convert';

import 'package:conecta_itt/login/services/password_recovery_session_controller.dart';
import 'package:conecta_itt/login/services/password_recovery_storage.dart';
import 'package:conecta_itt/login/services/supabase_password_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

class _MockSession extends Mock implements Session {}

class _MockUser extends Mock implements User {}

class _MockUserResponse extends Mock implements UserResponse {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserAttributes(password: 'fallback-password'));
  });

  group('SupabasePasswordRecoveryService', () {
    late _MockAuth auth;
    late PasswordRecoveryStorage storage;
    late PasswordRecoverySessionController controller;
    late SupabasePasswordRecoveryService service;

    String? persistedValue;
    Session? currentSession;

    Session createSession({
      String userId = 'user-1',
      String sessionId = 'session-1',
    }) {
      final session = _MockSession();
      final user = _MockUser();

      final claims = base64Url
          .encode(
            utf8.encode(jsonEncode({'sub': userId, 'session_id': sessionId})),
          )
          .replaceAll('=', '');

      when(() => user.id).thenReturn(userId);
      when(() => session.user).thenReturn(user);
      when(() => session.accessToken).thenReturn('e30.$claims.test-signature');

      return session;
    }

    setUp(() {
      persistedValue = null;
      currentSession = null;

      auth = _MockAuth();

      when(() => auth.currentSession).thenAnswer((_) => currentSession);

      when(() => auth.signOut(scope: SignOutScope.local)).thenAnswer((_) async {
        currentSession = null;
      });

      storage = PasswordRecoveryStorage.withOperations(
        read: () async => persistedValue,
        write: (value) async {
          persistedValue = value;
        },
        delete: () async {
          persistedValue = null;
        },
      );

      controller = PasswordRecoverySessionController(storage: storage);

      service = SupabasePasswordRecoveryService(
        auth: auth,
        controller: controller,
      );
    });

    Future<void> establishRecovery() async {
      final session = createSession();

      when(
        () => auth.verifyOTP(tokenHash: 'test-token', type: OtpType.recovery),
      ).thenAnswer((_) async {
        currentSession = session;

        return AuthResponse(session: session);
      });

      await service.verifyRecoveryTokenHash(tokenHash: 'test-token');
    }

    test('startup preserves a clean recovery context', () async {
      await service.initializeRecoveryContext();

      expect(await storage.read(), isNull);
      expect(currentSession, isNull);

      verifyNever(() => auth.signOut(scope: SignOutScope.local));
    });

    test('startup clears interrupted pending verification', () async {
      await controller.beginVerification();

      await service.initializeRecoveryContext();

      expect(await storage.read(), isNull);

      expect(
        await service.getStatus(),
        PasswordRecoverySessionStatus.signedOut,
      );
    });

    test('startup clears context of a lost temporary session', () async {
      await establishRecovery();

      // Simulate a process restart without a persisted session.
      currentSession = null;

      await service.initializeRecoveryContext();

      expect(await storage.read(), isNull);

      expect(
        await service.getStatus(),
        PasswordRecoverySessionStatus.signedOut,
      );
    });

    test('startup preserves an active matching recovery', () async {
      await establishRecovery();

      await service.initializeRecoveryContext();

      expect(currentSession, isNotNull);

      expect(await service.getStatus(), PasswordRecoverySessionStatus.recovery);

      verifyNever(() => auth.signOut(scope: SignOutScope.local));
    });

    test('requests recovery email without creating a session', () async {
      when(
        () => auth.resetPasswordForEmail(
          'student@example.com',
          redirectTo: 'mx.tecnm.tlalpan.conectaitt://password-recovery',
        ),
      ).thenAnswer((_) async {});

      await service.requestRecoveryEmail(email: ' STUDENT@example.com ');

      verify(
        () => auth.resetPasswordForEmail(
          'student@example.com',
          redirectTo: 'mx.tecnm.tlalpan.conectaitt://password-recovery',
        ),
      ).called(1);

      expect(currentSession, isNull);
      expect(await storage.read(), isNull);

      expect(
        await service.getStatus(),
        PasswordRecoverySessionStatus.signedOut,
      );
    });

    test('rejects an invalid recovery email', () {
      expect(
        () => service.requestRecoveryEmail(email: 'invalid-email'),
        throwsArgumentError,
      );

      verifyNever(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      );
    });

    test('rejects email requests during active recovery', () async {
      await establishRecovery();

      await expectLater(
        service.requestRecoveryEmail(email: 'student@example.com'),
        throwsStateError,
      );

      verifyNever(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      );
    });

    test('rejects email requests with pending context', () async {
      await controller.beginVerification();

      await expectLater(
        service.requestRecoveryEmail(email: 'student@example.com'),
        throwsStateError,
      );

      verifyNever(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      );
    });

    test('releases operation lock after email request fails', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenThrow(const AuthException('Recovery request failed'));

      await expectLater(
        service.requestRecoveryEmail(email: 'student@example.com'),
        throwsA(isA<AuthException>()),
      );

      expect(service.isBusy, isFalse);
      expect(currentSession, isNull);
      expect(await storage.read(), isNull);
    });

    test('reports signed out without a session', () async {
      expect(
        await service.getStatus(),
        PasswordRecoverySessionStatus.signedOut,
      );
    });

    test('persists marker before verifying a token', () async {
      final session = createSession();

      when(
        () => auth.verifyOTP(tokenHash: 'test-token', type: OtpType.recovery),
      ).thenAnswer((_) async {
        final context = await storage.read();

        expect(context, isNotNull);
        expect(context!.isPending, isTrue);

        currentSession = session;

        return AuthResponse(session: session);
      });

      await service.verifyRecoveryTokenHash(tokenHash: 'test-token');

      expect(await service.getStatus(), PasswordRecoverySessionStatus.recovery);
    });

    test('verifies an email recovery code', () async {
      final session = createSession();

      when(
        () => auth.verifyOTP(
          email: 'student@example.com',
          token: '123456',
          type: OtpType.recovery,
        ),
      ).thenAnswer((_) async {
        currentSession = session;

        return AuthResponse(session: session);
      });

      await service.verifyRecoveryCode(
        email: ' STUDENT@example.com ',
        code: '123456',
      );

      expect(await service.getStatus(), PasswordRecoverySessionStatus.recovery);
    });

    test('clears pending marker after invalid verification', () async {
      when(
        () =>
            auth.verifyOTP(tokenHash: 'invalid-token', type: OtpType.recovery),
      ).thenThrow(const AuthException('Invalid recovery token'));

      await expectLater(
        service.verifyRecoveryTokenHash(tokenHash: 'invalid-token'),
        throwsA(isA<AuthException>()),
      );

      expect(await storage.read(), isNull);
      expect(service.isBusy, isFalse);
    });

    test('does not replace an authenticated account', () async {
      currentSession = createSession();

      await expectLater(
        service.verifyRecoveryTokenHash(tokenHash: 'test-token'),
        throwsStateError,
      );

      expect(await storage.read(), isNull);

      verifyNever(
        () => auth.verifyOTP(tokenHash: 'test-token', type: OtpType.recovery),
      );
    });

    test('blocks update without verified recovery', () async {
      currentSession = createSession();

      await expectLater(
        service.completeRecovery(
          password: 'new-password',
          confirmation: 'new-password',
        ),
        throwsStateError,
      );

      verifyNever(() => auth.updateUser(any()));
    });

    test('rejects mismatched passwords', () {
      expect(
        () => service.completeRecovery(
          password: 'new-password',
          confirmation: 'different-password',
        ),
        throwsArgumentError,
      );

      verifyNever(() => auth.updateUser(any()));
    });

    test('rejects short passwords', () {
      expect(
        () => service.completeRecovery(password: '123', confirmation: '123'),
        throwsArgumentError,
      );

      verifyNever(() => auth.updateUser(any()));
    });

    test('updates password and closes recovery session', () async {
      await establishRecovery();

      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => _MockUserResponse());

      await service.completeRecovery(
        password: 'new-password',
        confirmation: 'new-password',
      );

      final attributes =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;

      expect(attributes.password, 'new-password');

      verify(() => auth.signOut(scope: SignOutScope.local)).called(1);

      expect(currentSession, isNull);
      expect(await storage.read(), isNull);
    });

    test('retains context when password update fails', () async {
      await establishRecovery();

      when(
        () => auth.updateUser(any()),
      ).thenThrow(const AuthException('Password update failed'));

      await expectLater(
        service.completeRecovery(
          password: 'new-password',
          confirmation: 'new-password',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(await service.getStatus(), PasswordRecoverySessionStatus.recovery);

      expect(service.isBusy, isFalse);
    });

    test('blocks password update after account change', () async {
      await establishRecovery();

      currentSession = createSession(
        userId: 'different-user',
        sessionId: 'different-session',
      );

      await expectLater(
        service.completeRecovery(
          password: 'new-password',
          confirmation: 'new-password',
        ),
        throwsStateError,
      );

      verifyNever(() => auth.updateUser(any()));
    });

    test('cancellation invalidates recovery session', () async {
      await establishRecovery();

      await service.cancelRecovery();

      expect(currentSession, isNull);
      expect(await storage.read(), isNull);
    });

    test('does not cancel an ordinary session', () async {
      currentSession = createSession();

      await expectLater(service.cancelRecovery(), throwsStateError);

      verifyNever(() => auth.signOut(scope: SignOutScope.local));
    });

    test('blocks simultaneous verification operations', () async {
      final started = Completer<void>();
      final response = Completer<AuthResponse>();
      final session = createSession();

      when(
        () => auth.verifyOTP(tokenHash: 'test-token', type: OtpType.recovery),
      ).thenAnswer((_) {
        started.complete();
        return response.future;
      });

      final first = service.verifyRecoveryTokenHash(tokenHash: 'test-token');

      await started.future;

      expect(service.isBusy, isTrue);

      await expectLater(
        service.verifyRecoveryTokenHash(tokenHash: 'second-token'),
        throwsStateError,
      );

      currentSession = session;

      response.complete(AuthResponse(session: session));

      await first;

      expect(service.isBusy, isFalse);

      expect(await service.getStatus(), PasswordRecoverySessionStatus.recovery);
    });
  });
}
