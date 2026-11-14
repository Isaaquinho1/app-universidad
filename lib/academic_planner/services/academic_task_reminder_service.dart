import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_verified_cancellation_service.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';

class AcademicTaskReminderService {
  AcademicTaskReminderService({
    required this.userId,
    this.coordinator,
    this.authRevision,
    LocalNotificationService? localNotificationService,
  }) : assert((coordinator == null) == (authRevision == null)),
       _localNotificationService =
           localNotificationService ?? LocalNotificationService.instance;

  final String userId;
  final AcademicReminderOperationCoordinator? coordinator;
  final int? authRevision;
  final LocalNotificationService _localNotificationService;

  Future<bool> requestPermission() {
    return _localNotificationService.requestNotificationPermission();
  }

  Future<bool> requestExactAlarmPermission() {
    return _localNotificationService.requestExactAlarmPermission();
  }

  Future<bool> canScheduleExactNotifications() {
    return _localNotificationService.canScheduleExactNotifications();
  }

  Future<void> synchronize(AcademicTask task) =>
      _synchronize(task, preserveMatching: false);

  Future<void> _synchronize(
    AcademicTask task, {
    required bool preserveMatching,
  }) {
    return _execute((lease) async {
      if (preserveMatching && _shouldSchedule(task)) {
        lease?.ensureCurrent();

        final pending =
            await _localNotificationService.pendingNotificationRequests();

        lease?.ensureCurrent();

        final id = AcademicReminderNotificationIdentity.forTask(
          userId: userId,
          taskId: task.id,
        );

        final sameSlot = pending.where((request) => request.id == id).toList();

        final signature = AcademicReminderScheduleIdentity.forTask(
          title: task.title,
          scheduledAt: task.reminderAt!,
        );

        if (sameSlot.length == 1 &&
            AcademicReminderVerifiedCancellationService.isMatchingSchedule(
              id: sameSlot.single.id,
              payload: sameSlot.single.payload,
              userId: userId,
              recordId: task.id,
              isTask: true,
              expectedSignature: signature,
            )) {
          lease?.ensureCurrent();
          return;
        }
      }

      // Primero comprobar colisiones. Nunca cancelar una alarma
      // propia si el mismo ID está ocupado por otra identidad.
      await AcademicReminderVerifiedCancellationService(
        localNotificationService: _localNotificationService,
      ).ensureSlotAvailable(
        userId: userId,
        recordId: task.id,
        isTask: true,
        ensureCurrent: lease?.ensureCurrent,
      );

      lease?.ensureCurrent();
      await _cancelDirect(task.id, lease);

      lease?.ensureCurrent();

      if (!_shouldSchedule(task)) {
        return;
      }

      final reminderAt = task.reminderAt!;

      lease?.ensureCurrent();

      await AcademicReminderVerifiedCancellationService(
        localNotificationService: _localNotificationService,
      ).ensureSlotAvailable(
        userId: userId,
        recordId: task.id,
        isTask: true,
        ensureCurrent: lease?.ensureCurrent,
      );

      lease?.ensureCurrent();

      await _localNotificationService.scheduleAcademicReminder(
        id: AcademicReminderNotificationIdentity.forTask(
          userId: userId,
          taskId: task.id,
        ),
        title: 'Tarea próxima',
        body: task.title,
        scheduledAt: reminderAt,
        payload: {
          'type': 'academic_task',
          'task_id': task.id,
          'user_id': userId,
          AcademicReminderScheduleIdentity.versionKey:
              AcademicReminderScheduleIdentity.version,
          AcademicReminderScheduleIdentity
              .signatureKey: AcademicReminderScheduleIdentity.forTask(
            title: task.title,
            scheduledAt: reminderAt,
          ),
        },
        ensureCurrent: lease?.ensureCurrent,
      );

      // El plugin pudo terminar después de un cambio de cuenta.
      // La reconciliación posterior atenderá cualquier alarma tardía.
      lease?.ensureCurrent();
    });
  }

  Future<void> cancel(String taskId) {
    return _execute((lease) => _cancelDirect(taskId, lease));
  }

  Future<void> _cancelDirect(
    String taskId,
    AcademicReminderOperationLease? lease,
  ) async {
    lease?.ensureCurrent();

    await AcademicReminderVerifiedCancellationService(
      localNotificationService: _localNotificationService,
    ).cancelOwned(
      userId: userId,
      recordId: taskId,
      isTask: true,
      ensureCurrent: lease?.ensureCurrent,
    );

    lease?.ensureCurrent();
  }

  Future<void> _execute(
    Future<void> Function(AcademicReminderOperationLease? lease) operation,
  ) async {
    final activeCoordinator = coordinator;

    if (activeCoordinator == null) {
      if (authRevision != null) {
        throw StateError('Falta el coordinador académico.');
      }
      await operation(null);
      return;
    }

    final revision = authRevision;
    if (revision == null) {
      throw StateError('Falta la revisión de autenticación.');
    }

    await activeCoordinator.run(
      userId: userId,
      revision: revision,
      operation: (lease) => operation(lease),
    );
  }

  Future<void> restore(Iterable<AcademicTask> tasks) async {
    for (final task in tasks) {
      await _synchronize(task, preserveMatching: true);
    }
  }

  bool _shouldSchedule(AcademicTask task) {
    final reminderAt = task.reminderAt;

    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      return false;
    }

    return task.status == AcademicTaskStatus.pending ||
        task.status == AcademicTaskStatus.inProgress;
  }

  int notificationIdForTask(String taskId) {
    const offsetBasis = 0x811C9DC5;
    const prime = 0x01000193;

    var hash = offsetBasis;

    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }

    // Reserva el rango superior para recordatorios académicos,
    // manteniendo el valor dentro de un entero positivo de 31 bits.
    return 0x40000000 | (hash & 0x3FFFFFFF);
  }
}
