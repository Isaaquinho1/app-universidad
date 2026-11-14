import 'dart:async';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_reminder_service.dart';
import 'package:conecta_itt/academic_planner/services/class_session_reminder_service.dart';
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
  Completer<void>? firstCancellationStarted;
  Completer<void>? releaseFirstCancellation;
  bool failQuery = false;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (failQuery) {
      throw StateError('Consulta simulada fallida');
    }

    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }

    return pending;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);

    if (cancelledIds.length == 1 && releaseFirstCancellation != null) {
      firstCancellationStarted?.complete();
      await releaseFirstCancellation!.future;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AcademicReminderOperationCoordinator coordinator;
  late _FakeNotifications notifications;

  int taskId(String uid, String id) =>
      AcademicReminderNotificationIdentity.forTask(userId: uid, taskId: id);

  int classId(String uid, String id) =>
      AcademicReminderNotificationIdentity.forClassSession(
        userId: uid,
        sessionId: id,
      );

  _Pending taskPending(String uid, String id) => _Pending(
    taskId(uid, id),
    '{"type":"academic_task","task_id":"$id","user_id":"$uid"}',
  );

  _Pending classPending(String uid, String id) => _Pending(
    classId(uid, id),
    '{"type":"class_session","session_id":"$id",'
    '"subject_id":"subject-1","user_id":"$uid"}',
  );

  AcademicTaskReminderService tasks(String uid, int revision) =>
      AcademicTaskReminderService(
        userId: uid,
        coordinator: coordinator,
        authRevision: revision,
        localNotificationService: notifications,
      );

  ClassSessionReminderService classes(String uid, int revision) =>
      ClassSessionReminderService(
        userId: uid,
        coordinator: coordinator,
        authRevision: revision,
        localNotificationService: notifications,
      );

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    notifications = _FakeNotifications();
  });

  test('la tarea vigente cancela solo la alarma verificada', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    notifications.pending = [taskPending('A', 'task-1')];

    await tasks('A', 1).cancel('task-1');

    expect(notifications.cancelledIds, [taskId('A', 'task-1')]);
  });

  test('la clase vigente cancela solo la alarma verificada', () async {
    coordinator.updateSession(userId: 'B', revision: 2);
    notifications.pending = [classPending('B', 'session-1')];

    await classes('B', 2).cancel('session-1');

    expect(notifications.cancelledIds, [classId('B', 'session-1')]);
  });

  test('no cancela alarmas de otra cuenta ni institucionales', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final requestedId = taskId('A', 'task-1');

    notifications.pending = [
      _Pending(
        requestedId,
        '{"type":"academic_task","task_id":"task-1",'
        '"user_id":"B"}',
      ),
    ];

    await tasks('A', 1).cancel('task-1');
    expect(notifications.cancelledIds, isEmpty);

    notifications.pending = [
      _Pending(
        requestedId,
        '{"type":"announcement","announcement_id":"news-1"}',
      ),
    ];

    await tasks('A', 1).cancel('task-1');
    expect(notifications.cancelledIds, isEmpty);
  });

  test('invalidación durante consulta impide cancelar', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    notifications.pendingCompleter =
        Completer<List<PendingNotificationRequest>>();

    final operation = tasks('A', 1).cancel('task-1');
    final assertion = expectLater(operation, throwsStateError);

    // Dejamos que comience la operación asíncrona.
    await Future<void>.delayed(Duration.zero);

    coordinator.updateSession(userId: 'B', revision: 2);

    notifications.pendingCompleter!.complete([taskPending('A', 'task-1')]);

    await assertion;
    expect(notifications.cancelledIds, isEmpty);
  });

  test('invalidación durante cancelación no inicia otra acción', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    notifications.pending = [taskPending('A', 'task-1')];
    notifications.firstCancellationStarted = Completer<void>();
    notifications.releaseFirstCancellation = Completer<void>();

    final operation = tasks('A', 1).cancel('task-1');
    final assertion = expectLater(operation, throwsStateError);

    await notifications.firstCancellationStarted!.future;

    coordinator.updateSession(userId: 'B', revision: 2);
    notifications.releaseFirstCancellation!.complete();

    await assertion;

    expect(notifications.cancelledIds, [taskId('A', 'task-1')]);
  });

  test('la cancelación verificada respeta la cola compartida', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    notifications.pending = [
      taskPending('A', 'task-1'),
      classPending('A', 'session-1'),
    ];

    notifications.firstCancellationStarted = Completer<void>();
    notifications.releaseFirstCancellation = Completer<void>();

    final first = tasks('A', 1).cancel('task-1');

    await notifications.firstCancellationStarted!.future;

    final second = classes('A', 1).cancel('session-1');

    expect(notifications.cancelledIds, [taskId('A', 'task-1')]);

    notifications.releaseFirstCancellation!.complete();

    await first;
    await second;

    expect(notifications.cancelledIds, [
      taskId('A', 'task-1'),
      classId('A', 'session-1'),
    ]);
  });

  test('A-B-A rechaza servicios de una revisión anterior', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final oldService = tasks('A', 1);

    coordinator.updateSession(userId: 'B', revision: 2);
    coordinator.updateSession(userId: 'A', revision: 3);

    notifications.pending = [taskPending('A', 'task-1')];

    await oldService.cancel('task-1');
    expect(notifications.cancelledIds, isEmpty);

    await tasks('A', 3).cancel('task-1');

    expect(notifications.cancelledIds, [taskId('A', 'task-1')]);
  });

  test('un error de consulta no cancela ninguna alarma', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    notifications.failQuery = true;

    await expectLater(tasks('A', 1).cancel('task-1'), throwsStateError);

    expect(notifications.cancelledIds, isEmpty);
  });
}
