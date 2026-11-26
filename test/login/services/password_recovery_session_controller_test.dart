import 'dart:convert';

import 'package:conecta_itt/login/services/password_recovery_session_controller.dart';
import 'package:conecta_itt/login/services/password_recovery_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordRecoverySessionController', () {
    String? persistedValue;

    late PasswordRecoveryStorage storage;
    late PasswordRecoverySessionController controller;

    final session = RecoverySessionIdentity(
      userId: 'user-1',
      sessionId: 'session-1',
    );

    final anotherSession = RecoverySessionIdentity(
      userId: 'user-1',
      sessionId: 'session-2',
    );

    final anotherUser = RecoverySessionIdentity(
      userId: 'user-2',
      sessionId: 'session-3',
    );

    PasswordRecoveryStorage createStorage() {
      return PasswordRecoveryStorage.withOperations(
        read: () async => persistedValue,
        write: (value) async {
          persistedValue = value;
        },
        delete: () async {
          persistedValue = null;
        },
      );
    }

    setUp(() {
      persistedValue = null;
      storage = createStorage();
      controller = PasswordRecoverySessionController(storage: storage);
    });

    Future<void> establishRecovery() async {
      await controller.beginVerification();
      await controller.bindVerifiedSession(session);
    }

    test('classifies an ordinary authenticated session', () async {
      expect(
        await controller.classify(session),
        PasswordRecoverySessionStatus.normal,
      );
    });

    test('classifies a signed out session', () async {
      expect(
        await controller.classify(null),
        PasswordRecoverySessionStatus.signedOut,
      );
    });

    test('persists pending verification', () async {
      await controller.beginVerification();

      expect(
        await controller.classify(null),
        PasswordRecoverySessionStatus.pending,
      );
    });

    test('blocks an unbound authenticated session', () async {
      await controller.beginVerification();

      expect(
        await controller.classify(session),
        PasswordRecoverySessionStatus.blocked,
      );
    });

    test('recognizes a verified recovery session', () async {
      await establishRecovery();

      expect(
        await controller.classify(session),
        PasswordRecoverySessionStatus.recovery,
      );
    });

    test('restores recovery after restarting', () async {
      await establishRecovery();

      final restarted = PasswordRecoverySessionController(
        storage: createStorage(),
      );

      expect(
        await restarted.classify(session),
        PasswordRecoverySessionStatus.recovery,
      );
    });

    test('recognizes the same session after token renewal', () async {
      await establishRecovery();

      final renewed = RecoverySessionIdentity(
        userId: 'user-1',
        sessionId: 'session-1',
      );

      expect(
        await controller.classify(renewed),
        PasswordRecoverySessionStatus.recovery,
      );
    });

    test('blocks another session of the same user', () async {
      await establishRecovery();

      expect(
        await controller.classify(anotherSession),
        PasswordRecoverySessionStatus.blocked,
      );
    });

    test('blocks a different account', () async {
      await establishRecovery();

      expect(
        await controller.classify(anotherUser),
        PasswordRecoverySessionStatus.blocked,
      );
    });

    test('does not clear mismatched recovery context', () async {
      await establishRecovery();

      await controller.classify(anotherUser);

      expect(await storage.read(), isNotNull);
    });

    test('rejects password update in a normal session', () async {
      expect(await controller.canUpdatePassword(session), isFalse);
    });

    test('allows a matching recovery context', () async {
      await establishRecovery();

      expect(await controller.canUpdatePassword(session), isTrue);
    });

    test('rejects password update for another account', () async {
      await establishRecovery();

      expect(await controller.canUpdatePassword(anotherUser), isFalse);
    });

    test('rejects binding without pending verification', () async {
      await expectLater(
        controller.bindVerifiedSession(session),
        throwsStateError,
      );
    });

    test('rejects replacing an existing recovery context', () async {
      await establishRecovery();

      await expectLater(controller.beginVerification(), throwsStateError);
    });

    test('rejects clearing while a session remains active', () async {
      await establishRecovery();

      await expectLater(
        controller.clearAfterSignOut(currentSession: session),
        throwsStateError,
      );

      expect(await storage.read(), isNotNull);
    });

    test('clears context after confirmed sign-out', () async {
      await establishRecovery();

      await controller.clearAfterSignOut(currentSession: null);

      expect(await storage.read(), isNull);
    });

    test('blocks corrupted recovery context', () async {
      persistedValue = 'invalid-json';

      expect(
        await controller.classify(session),
        PasswordRecoverySessionStatus.blocked,
      );
    });

    test('blocks storage failures', () async {
      final failing = PasswordRecoverySessionController(
        storage: PasswordRecoveryStorage.withOperations(
          read: () async => throw StateError('Storage unavailable'),
          write: (_) async {},
          delete: () async {},
        ),
      );

      expect(
        await failing.classify(session),
        PasswordRecoverySessionStatus.blocked,
      );
    });
  });

  group('RecoverySessionIdentity', () {
    String token(Map<String, dynamic> claims) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode(claims)))
          .replaceAll('=', '');

      return 'e30.$payload.test-signature';
    }

    test('extracts session identity from JWT claims', () {
      final identity = RecoverySessionIdentity.fromAccessToken(
        userId: 'user-1',
        accessToken: token({'sub': 'user-1', 'session_id': 'session-1'}),
      );

      expect(identity.userId, 'user-1');
      expect(identity.sessionId, 'session-1');
    });

    test('rejects mismatched subject', () {
      expect(
        () => RecoverySessionIdentity.fromAccessToken(
          userId: 'user-1',
          accessToken: token({'sub': 'user-2', 'session_id': 'session-1'}),
        ),
        throwsFormatException,
      );
    });

    test('rejects missing session identifier', () {
      expect(
        () => RecoverySessionIdentity.fromAccessToken(
          userId: 'user-1',
          accessToken: token({'sub': 'user-1'}),
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed JWT', () {
      expect(
        () => RecoverySessionIdentity.fromAccessToken(
          userId: 'user-1',
          accessToken: 'invalid-token',
        ),
        throwsFormatException,
      );
    });
  });
}
