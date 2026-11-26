import 'dart:convert';

import 'package:conecta_itt/login/services/password_recovery_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordRecoveryStorage', () {
    String? persistedValue;
    late PasswordRecoveryStorage storage;

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
    });

    test('returns null when no context exists', () async {
      expect(await storage.read(), isNull);
    });

    test('persists pending recovery', () async {
      await storage.markPending();

      final context = await storage.read();

      expect(context, isNotNull);
      expect(context!.isPending, isTrue);
    });

    test('binds recovery to a specific session', () async {
      await storage.bindSession(userId: 'user-1', sessionId: 'session-1');

      final context = (await storage.read())!;

      expect(context.isPending, isFalse);

      expect(
        context.matchesSession(userId: 'user-1', sessionId: 'session-1'),
        isTrue,
      );
    });

    test('restores context with a new storage instance', () async {
      await storage.bindSession(userId: 'user-1', sessionId: 'session-1');

      final restartedStorage = createStorage();
      final context = (await restartedStorage.read())!;

      expect(context.userId, 'user-1');
      expect(context.sessionId, 'session-1');
    });

    test('rejects a different account', () async {
      await storage.bindSession(userId: 'user-1', sessionId: 'session-1');

      final context = (await storage.read())!;

      expect(
        context.matchesSession(userId: 'user-2', sessionId: 'session-1'),
        isFalse,
      );
    });

    test('rejects a different session of the same user', () async {
      await storage.bindSession(userId: 'user-1', sessionId: 'session-1');

      final context = (await storage.read())!;

      expect(
        context.matchesSession(userId: 'user-1', sessionId: 'session-2'),
        isFalse,
      );
    });

    test('pending recovery cannot authorize a session', () async {
      await storage.markPending();

      final context = (await storage.read())!;

      expect(
        context.matchesSession(userId: 'user-1', sessionId: 'session-1'),
        isFalse,
      );
    });

    test('rejects empty identifiers', () {
      expect(
        () => PasswordRecoveryContext.bound(userId: '', sessionId: 'session-1'),
        throwsArgumentError,
      );

      expect(
        () => PasswordRecoveryContext.bound(userId: 'user-1', sessionId: ''),
        throwsArgumentError,
      );
    });

    test('clears the recovery context', () async {
      await storage.markPending();
      await storage.clear();

      expect(await storage.read(), isNull);
    });

    test('rejects corrupted storage', () async {
      persistedValue = 'invalid-json';

      await expectLater(storage.read(), throwsFormatException);
    });

    test('rejects unsupported storage versions', () async {
      persistedValue = jsonEncode({'version': 99, 'status': 'pending'});

      await expectLater(storage.read(), throwsFormatException);
    });

    test('propagates storage read errors', () async {
      final failingStorage = PasswordRecoveryStorage.withOperations(
        read: () async => throw StateError('Storage unavailable'),
        write: (_) async {},
        delete: () async {},
      );

      await expectLater(failingStorage.read(), throwsStateError);
    });

    test('propagates storage write errors', () async {
      final failingStorage = PasswordRecoveryStorage.withOperations(
        read: () async => null,
        write: (_) async => throw StateError('Storage unavailable'),
        delete: () async {},
      );

      await expectLater(failingStorage.markPending(), throwsStateError);
    });

    test('propagates storage deletion errors', () async {
      final failingStorage = PasswordRecoveryStorage.withOperations(
        read: () async => null,
        write: (_) async {},
        delete: () async => throw StateError('Storage unavailable'),
      );

      await expectLater(failingStorage.clear(), throwsStateError);
    });
  });
}
