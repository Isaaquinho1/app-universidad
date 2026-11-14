import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_verified_cancellation_service.dart';
import 'dart:async';

import 'package:conecta_itt/app/services/local_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pending implements PendingNotificationRequest {
  _Pending(this.id, this.payload);

  @override
  final int id;

  @override
  final String? payload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotifications implements LocalNotificationService {
  List<PendingNotificationRequest> pending = [];
  final cancelledIds = <int>[];

  Completer<List<PendingNotificationRequest>>? pendingCompleter;
  bool failQuery = false;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (failQuery) {
      throw StateError('Consulta simulada fallida');
    }

    final completer = pendingCompleter;
    if (completer != null) {
      return completer.future;
    }

    return pending;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const user = 'student-A';

  bool matches({
    required int id,
    required String? payload,
    String userId = user,
    String recordId = 'task-1',
    bool isTask = true,
  }) {
    return AcademicReminderVerifiedCancellationService.isOwnedNotification(
      id: id,
      payload: payload,
      userId: userId,
      recordId: recordId,
      isTask: isTask,
    );
  }

  group('Cancelación académica verificada', () {
    final taskId = AcademicReminderNotificationIdentity.forTask(
      userId: user,
      taskId: 'task-1',
    );

    final classId = AcademicReminderNotificationIdentity.forClassSession(
      userId: user,
      sessionId: 'session-1',
    );

    test('reconoce una tarea de la cuenta activa', () {
      expect(
        matches(
          id: taskId,
          payload:
              '{"type":"academic_task","task_id":"task-1",'
              '"user_id":"student-A"}',
        ),
        isTrue,
      );
    });

    test('rechaza una tarea de otra cuenta', () {
      expect(
        matches(
          id: taskId,
          payload:
              '{"type":"academic_task","task_id":"task-1",'
              '"user_id":"student-B"}',
        ),
        isFalse,
      );
    });

    test('rechaza un registro académico diferente', () {
      expect(
        matches(
          id: taskId,
          payload:
              '{"type":"academic_task","task_id":"task-2",'
              '"user_id":"student-A"}',
        ),
        isFalse,
      );
    });

    test('rechaza una alarma heredada sin UID', () {
      expect(
        matches(
          id: taskId,
          payload: '{"type":"academic_task","task_id":"task-1"}',
        ),
        isFalse,
      );
    });

    test('reconoce una sesión válida con materia', () {
      expect(
        matches(
          id: classId,
          recordId: 'session-1',
          isTask: false,
          payload:
              '{"type":"class_session","session_id":"session-1",'
              '"subject_id":"subject-1","user_id":"student-A"}',
        ),
        isTrue,
      );
    });

    test('rechaza una clase sin materia', () {
      expect(
        matches(
          id: classId,
          recordId: 'session-1',
          isTask: false,
          payload:
              '{"type":"class_session","session_id":"session-1",'
              '"user_id":"student-A"}',
        ),
        isFalse,
      );
    });

    test('rechaza tipos institucionales', () {
      expect(
        matches(
          id: taskId,
          payload:
              '{"type":"announcement","task_id":"task-1",'
              '"user_id":"student-A"}',
        ),
        isFalse,
      );
    });

    test('rechaza hash incompatible y payload malformado', () {
      expect(
        matches(
          id: taskId == 1 ? 2 : taskId - 1,
          payload:
              '{"type":"academic_task","task_id":"task-1",'
              '"user_id":"student-A"}',
        ),
        isFalse,
      );

      expect(matches(id: taskId, payload: '{error'), isFalse);
      expect(matches(id: taskId, payload: null), isFalse);
    });
  });

  group('cancelOwned respeta la propiedad y la sesión', () {
    const userId = 'student-A';
    const taskId = 'task-1';

    final notificationId = AcademicReminderNotificationIdentity.forTask(
      userId: userId,
      taskId: taskId,
    );

    const ownedPayload =
        '{"type":"academic_task","task_id":"task-1",'
        '"user_id":"student-A"}';

    test('cancela únicamente la alarma propia verificada', () async {
      final fake = _FakeNotifications();
      fake.pending = [_Pending(notificationId, ownedPayload)];

      final service = AcademicReminderVerifiedCancellationService(
        localNotificationService: fake,
      );

      final cancelled = await service.cancelOwned(
        userId: userId,
        recordId: taskId,
        isTask: true,
      );

      expect(cancelled, isTrue);
      expect(fake.cancelledIds, [notificationId]);
    });

    test('conserva otra cuenta aunque coincida el ID', () async {
      final fake = _FakeNotifications();
      fake.pending = [
        _Pending(
          notificationId,
          '{"type":"academic_task","task_id":"task-1",'
          '"user_id":"student-B"}',
        ),
      ];

      final service = AcademicReminderVerifiedCancellationService(
        localNotificationService: fake,
      );

      final cancelled = await service.cancelOwned(
        userId: userId,
        recordId: taskId,
        isTask: true,
      );

      expect(cancelled, isFalse);
      expect(fake.cancelledIds, isEmpty);
    });

    test('conserva una notificación institucional', () async {
      final fake = _FakeNotifications();
      fake.pending = [
        _Pending(
          notificationId,
          '{"type":"announcement","announcement_id":"news-1"}',
        ),
      ];

      final service = AcademicReminderVerifiedCancellationService(
        localNotificationService: fake,
      );

      final cancelled = await service.cancelOwned(
        userId: userId,
        recordId: taskId,
        isTask: true,
      );

      expect(cancelled, isFalse);
      expect(fake.cancelledIds, isEmpty);
    });

    test('un error de consulta no provoca cancelaciones', () async {
      final fake = _FakeNotifications()..failQuery = true;
      final service = AcademicReminderVerifiedCancellationService(
        localNotificationService: fake,
      );

      await expectLater(
        service.cancelOwned(userId: userId, recordId: taskId, isTask: true),
        throwsStateError,
      );

      expect(fake.cancelledIds, isEmpty);
    });

    test('invalidación durante la consulta impide cancelar', () async {
      final fake = _FakeNotifications();
      fake.pendingCompleter = Completer<List<PendingNotificationRequest>>();

      final service = AcademicReminderVerifiedCancellationService(
        localNotificationService: fake,
      );

      var current = true;

      void ensureCurrent() {
        if (!current) {
          throw StateError('Sesión académica invalidada');
        }
      }

      final operation = service.cancelOwned(
        userId: userId,
        recordId: taskId,
        isTask: true,
        ensureCurrent: ensureCurrent,
      );

      final assertion = expectLater(operation, throwsStateError);

      current = false;
      fake.pendingCompleter!.complete([_Pending(notificationId, ownedPayload)]);

      await assertion;
      expect(fake.cancelledIds, isEmpty);
    });
  });
}
