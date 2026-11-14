import 'dart:async';
import 'dart:convert';

import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
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

class _Notifications implements LocalNotificationService {
  final pending = <PendingNotificationRequest>[];
  final cancelled = <int>[];
  final scheduledTasks = <int>[];
  final scheduledClasses = <int>[];

  bool failQuery = false;
  Completer<List<PendingNotificationRequest>>? pendingGate;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (failQuery) {
      throw StateError('Consulta simulada fallida');
    }

    if (pendingGate != null) {
      return pendingGate!.future;
    }

    return List<PendingNotificationRequest>.of(pending);
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
    pending.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> scheduleAcademicReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required Map<String, dynamic> payload,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    scheduledTasks.add(id);
    pending.removeWhere((item) => item.id == id);
    pending.add(_Pending(id, jsonEncode(payload)));
    ensureCurrent?.call();
  }

  @override
  Future<void> scheduleWeeklyAcademicReminder({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    required Map<String, dynamic> payload,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    scheduledClasses.add(id);
    pending.removeWhere((item) => item.id == id);
    pending.add(_Pending(id, jsonEncode(payload)));
    ensureCurrent?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'student-A';
  const revision = 1;
  const taskRecord = 'task-1';
  const classRecord = 'session-1';
  const subjectRecord = 'subject-1';

  late _Notifications notifications;
  late AcademicReminderOperationCoordinator coordinator;
  late AcademicTaskReminderService taskService;
  late ClassSessionReminderService classService;

  final created = DateTime(2026, 10, 1);

  AcademicTask task({String title = 'Proyecto final'}) {
    return AcademicTask(
      id: taskRecord,
      title: title,
      priority: TaskPriority.fromDatabase(null),
      status: AcademicTaskStatus.pending,
      reminderAt: DateTime.now().add(const Duration(days: 10)),
      createdAt: created,
      updatedAt: created,
    );
  }

  AcademicSubject subject() {
    return AcademicSubject(
      id: subjectRecord,
      name: 'Redes',
      colorValue: 0xFF123456,
      createdAt: created,
      updatedAt: created,
    );
  }

  ClassSession session({int startMinutes = 540}) {
    return ClassSession(
      id: classRecord,
      subjectId: subjectRecord,
      weekday: DateTime.monday,
      startMinutes: startMinutes,
      endMinutes: startMinutes + 60,
      reminderMinutes: 15,
      building: 'A',
      room: '101',
      createdAt: created,
      updatedAt: created,
    );
  }

  int taskId() => AcademicReminderNotificationIdentity.forTask(
    userId: uid,
    taskId: taskRecord,
  );

  int classId() => AcademicReminderNotificationIdentity.forClassSession(
    userId: uid,
    sessionId: classRecord,
  );

  _Pending taskPending(AcademicTask item, {bool signed = true}) {
    return _Pending(
      taskId(),
      jsonEncode({
        'type': 'academic_task',
        'task_id': item.id,
        'user_id': uid,
        if (signed) ...{
          AcademicReminderScheduleIdentity.versionKey:
              AcademicReminderScheduleIdentity.version,
          AcademicReminderScheduleIdentity
              .signatureKey: AcademicReminderScheduleIdentity.forTask(
            title: item.title,
            scheduledAt: item.reminderAt!,
          ),
        },
      }),
    );
  }

  _Pending classPending(
    ClassSession item,
    AcademicSubject course, {
    bool signed = true,
  }) {
    final totalMinutes = item.startMinutes - item.reminderMinutes!;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final body = '${course.name} · ${item.building} · ${item.room}';

    return _Pending(
      classId(),
      jsonEncode({
        'type': 'class_session',
        'session_id': item.id,
        'subject_id': course.id,
        'user_id': uid,
        if (signed) ...{
          AcademicReminderScheduleIdentity.versionKey:
              AcademicReminderScheduleIdentity.version,
          AcademicReminderScheduleIdentity
              .signatureKey: AcademicReminderScheduleIdentity.forClassSession(
            body: body,
            weekday: item.weekday,
            hour: hour,
            minute: minute,
          ),
        },
      }),
    );
  }

  setUp(() {
    notifications = _Notifications();
    coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: uid, revision: revision);

    taskService = AcademicTaskReminderService(
      userId: uid,
      coordinator: coordinator,
      authRevision: revision,
      localNotificationService: notifications,
    );

    classService = ClassSessionReminderService(
      userId: uid,
      coordinator: coordinator,
      authRevision: revision,
      localNotificationService: notifications,
    );
  });

  test('tarea con firma coincidente no cancela ni programa', () async {
    final item = task();
    notifications.pending.add(taskPending(item));

    await taskService.restore([item]);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, isEmpty);
    expect(notifications.pending, hasLength(1));
  });

  test('clase con firma coincidente no cancela ni programa', () async {
    final item = session();
    final course = subject();

    notifications.pending.add(classPending(item, course));

    await classService.restore(
      sessions: [item],
      subjectsById: {course.id: course},
    );

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledClasses, isEmpty);
    expect(notifications.pending, hasLength(1));
  });

  test('tarea ausente se programa una sola vez', () async {
    final item = task();

    await taskService.restore([item]);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, [taskId()]);
    expect(notifications.pending, hasLength(1));

    // Segunda restauración debe conservar la nueva programación.
    await taskService.restore([item]);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, [taskId()]);
  });

  test('clase ausente se programa una sola vez', () async {
    final item = session();
    final course = subject();

    await classService.restore(
      sessions: [item],
      subjectsById: {course.id: course},
    );

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledClasses, [classId()]);

    await classService.restore(
      sessions: [item],
      subjectsById: {course.id: course},
    );

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledClasses, [classId()]);
  });

  test('firma antigua de tarea se actualiza', () async {
    final previous = task(title: 'Título anterior');
    final updated = AcademicTask(
      id: taskRecord,
      title: 'Proyecto actualizado',
      priority: previous.priority,
      status: previous.status,
      reminderAt: previous.reminderAt,
      createdAt: previous.createdAt,
      updatedAt: previous.updatedAt,
    );

    notifications.pending.add(taskPending(previous));

    await taskService.restore([updated]);

    expect(notifications.cancelled, [taskId()]);
    expect(notifications.scheduledTasks, [taskId()]);

    await taskService.restore([updated]);

    expect(notifications.cancelled, [taskId()]);
    expect(notifications.scheduledTasks, [taskId()]);
  });

  test('firma antigua de clase se actualiza', () async {
    final previous = session(startMinutes: 540);
    final updated = session(startMinutes: 600);
    final course = subject();

    notifications.pending.add(classPending(previous, course));

    await classService.restore(
      sessions: [updated],
      subjectsById: {course.id: course},
    );

    expect(notifications.cancelled, [classId()]);
    expect(notifications.scheduledClasses, [classId()]);

    await classService.restore(
      sessions: [updated],
      subjectsById: {course.id: course},
    );

    expect(notifications.cancelled, [classId()]);
    expect(notifications.scheduledClasses, [classId()]);
  });

  test('colisión institucional no cancela ni programa', () async {
    notifications.pending.add(
      _Pending(
        taskId(),
        jsonEncode({'type': 'announcement', 'announcement_id': 'news-1'}),
      ),
    );

    await expectLater(taskService.restore([task()]), throwsStateError);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, isEmpty);
  });

  test('consulta fallida no cancela ni programa', () async {
    notifications.failQuery = true;

    await expectLater(taskService.restore([task()]), throwsStateError);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, isEmpty);
  });

  test('cambio de cuenta durante consulta impide programar', () async {
    notifications.pendingGate = Completer<List<PendingNotificationRequest>>();

    final operation = taskService.restore([task()]);
    final assertion = expectLater(operation, throwsStateError);

    // Dar oportunidad de iniciar la consulta asíncrona.
    await Future<void>.delayed(Duration.zero);

    coordinator.updateSession(userId: 'student-B', revision: 2);
    notifications.pendingGate!.complete([]);

    await assertion;

    expect(notifications.cancelled, isEmpty);
    expect(notifications.scheduledTasks, isEmpty);
  });
}
