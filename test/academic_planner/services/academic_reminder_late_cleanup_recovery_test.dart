import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
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

class _Notifications implements LocalNotificationService {
  final pending = <PendingNotificationRequest>[];
  final cancelled = <int>[];

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => List.of(pending);

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
    pending.removeWhere((request) => request.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_Pending _task(String owner, String recordId) {
  return _Pending(
    AcademicReminderNotificationIdentity.forTask(
      userId: owner,
      taskId: recordId,
    ),
    '{"type":"academic_task",'
    '"task_id":"$recordId","user_id":"$owner"}',
  );
}

_Pending _classReminder(String owner, String recordId) {
  return _Pending(
    AcademicReminderNotificationIdentity.forClassSession(
      userId: owner,
      sessionId: recordId,
    ),
    '{"type":"class_session",'
    '"session_id":"$recordId",'
    '"subject_id":"subject-1","user_id":"$owner"}',
  );
}

void main() {
  test('segunda limpieza retira alarma de A que apareció tarde', () async {
    final notifications = _Notifications();
    final cleanup = AcademicReminderPendingCleanupService(
      localNotificationService: notifications,
    );

    // B inicia sesión: todavía no aparece la alarma tardía de A.
    expect(await cleanup.cancelForeignAndLegacy(activeUserId: 'B'), 0);

    final lateAlarm = _task('A', 'task-late');
    notifications.pending.add(lateAlarm);

    // Una reconciliación posterior de B vuelve a comprobar pendientes.
    expect(await cleanup.cancelForeignAndLegacy(activeUserId: 'B'), 1);

    expect(notifications.cancelled, [lateAlarm.id]);
    expect(notifications.pending, isEmpty);
  });

  test('recuperación conserva alarmas legítimas de B', () async {
    final notifications = _Notifications();
    final cleanup = AcademicReminderPendingCleanupService(
      localNotificationService: notifications,
    );

    final oldTask = _task('A', 'task-old');
    final ownTask = _task('B', 'task-own');
    final ownClass = _classReminder('B', 'class-own');

    notifications.pending.addAll([oldTask, ownTask, ownClass]);

    expect(await cleanup.cancelForeignAndLegacy(activeUserId: 'B'), 1);

    expect(notifications.cancelled, [oldTask.id]);
    expect(
      notifications.pending.map((request) => request.id),
      containsAll([ownTask.id, ownClass.id]),
    );
  });

  test('recuperación conserva alarmas institucionales y heredadas', () async {
    final notifications = _Notifications();
    final cleanup = AcademicReminderPendingCleanupService(
      localNotificationService: notifications,
    );

    final announcement = _Pending(
      0x50000001,
      '{"type":"announcement","announcement_id":"news-1"}',
    );

    final legacy = _Pending(
      0x40000001,
      '{"type":"academic_task","task_id":"legacy-1"}',
    );

    final unknown = _Pending(
      0x00000002,
      '{"type":"academic_task","task_id":"unknown-1"}',
    );

    notifications.pending.addAll([announcement, legacy, unknown]);

    expect(await cleanup.cancelForeignAndLegacy(activeUserId: 'B'), 0);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.pending, hasLength(3));
  });
}
