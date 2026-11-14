import 'dart:async';

import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_reminder_service.dart';
import 'package:conecta_itt/academic_planner/services/class_session_reminder_service.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedNotifications implements LocalNotificationService {
  final started = Completer<void>();
  final release = Completer<void>();

  int scheduledCount = 0;
  void Function()? receivedEnsureCurrent;

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [];

  Future<void> _schedule() async {
    scheduledCount++;
    started.complete();
    await release.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #scheduleWeeklyAcademicReminder ||
        invocation.memberName == #scheduleAcademicReminder) {
      receivedEnsureCurrent =
          invocation.namedArguments[#ensureCurrent] as void Function()?;
      return _schedule();
    }

    return super.noSuchMethod(invocation);
  }
}

void main() {
  final now = DateTime.now();

  final subject = AcademicSubject(
    id: 'subject-1',
    name: 'Redes',
    colorValue: 0xFF123456,
    createdAt: now,
    updatedAt: now,
  );

  final session = ClassSession(
    id: 'session-1',
    subjectId: 'subject-1',
    weekday: DateTime.monday,
    startMinutes: 600,
    endMinutes: 660,
    reminderMinutes: 15,
    createdAt: now,
    updatedAt: now,
  );

  test('tarea transmite ensureCurrent al programar', () async {
    final now = DateTime.now();
    final task = AcademicTask(
      id: 'task-1',
      title: 'Entregar proyecto de Redes',
      priority: TaskPriority.fromDatabase('medium'),
      status: AcademicTaskStatus.pending,
      reminderAt: now.add(const Duration(days: 1)),
      createdAt: now,
      updatedAt: now,
    );

    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = AcademicTaskReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(task);

    await notifications.started.future;

    final verifier = notifications.receivedEnsureCurrent;
    expect(verifier, isNotNull);
    expect(verifier!, returnsNormally);

    notifications.release.complete();
    await operation;

    expect(notifications.scheduledCount, 1);
  });

  test('verificador de tarea rechaza cuenta anterior', () async {
    final now = DateTime.now();
    final task = AcademicTask(
      id: 'task-2',
      title: 'Preparar examen',
      priority: TaskPriority.fromDatabase('medium'),
      status: AcademicTaskStatus.pending,
      reminderAt: now.add(const Duration(days: 1)),
      createdAt: now,
      updatedAt: now,
    );

    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = AcademicTaskReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(task);
    final assertion = expectLater(operation, throwsStateError);

    await notifications.started.future;

    final verifier = notifications.receivedEnsureCurrent;
    expect(verifier, isNotNull);

    coordinator.updateSession(userId: 'B', revision: 2);

    expect(verifier!, throwsStateError);

    notifications.release.complete();
    await assertion;

    // El simulador ya había recibido la solicitud.
    // Detectar la cuenta obsoleta no implica cancelarla.
    expect(notifications.scheduledCount, 1);
  });

  test('programación vigente termina correctamente', () async {
    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = ClassSessionReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(session: session, subject: subject);

    await notifications.started.future;
    notifications.release.complete();

    await operation;

    expect(notifications.scheduledCount, 1);
  });

  test('transmite ensureCurrent al programar clases', () async {
    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = ClassSessionReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(session: session, subject: subject);

    await notifications.started.future;

    final verifier = notifications.receivedEnsureCurrent;

    expect(verifier, isNotNull);
    expect(verifier!, returnsNormally);

    notifications.release.complete();
    await operation;

    expect(notifications.scheduledCount, 1);
  });

  test('ensureCurrent recibido rechaza una cuenta anterior', () async {
    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = ClassSessionReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(session: session, subject: subject);

    final assertion = expectLater(operation, throwsStateError);

    await notifications.started.future;

    final verifier = notifications.receivedEnsureCurrent;
    expect(verifier, isNotNull);

    coordinator.updateSession(userId: 'B', revision: 2);

    expect(verifier!, throwsStateError);

    notifications.release.complete();
    await assertion;

    // El simulador ya recibió la solicitud de programación.
    // Invalidar la sesión no equivale a cancelar esa solicitud.
    expect(notifications.scheduledCount, 1);
  });

  test('programación tardía detecta sesión obsoleta', () async {
    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final notifications = _DelayedNotifications();

    final service = ClassSessionReminderService(
      userId: 'A',
      coordinator: coordinator,
      authRevision: 1,
      localNotificationService: notifications,
    );

    final operation = service.synchronize(session: session, subject: subject);

    final assertion = expectLater(operation, throwsStateError);

    await notifications.started.future;

    coordinator.updateSession(userId: 'B', revision: 2);
    notifications.release.complete();

    await assertion;

    // Detectar la sesión obsoleta no revierte la llamada al plugin.
    expect(notifications.scheduledCount, 1);
  });
}
