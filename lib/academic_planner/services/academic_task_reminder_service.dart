import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';

class AcademicTaskReminderService {
  AcademicTaskReminderService({
    LocalNotificationService? localNotificationService,
  }) : _localNotificationService =
           localNotificationService ?? LocalNotificationService.instance;

  final LocalNotificationService _localNotificationService;

  Future<bool> requestPermission() {
    return _localNotificationService.requestNotificationPermission();
  }

  Future<bool> requestExactAlarmPermission() {
    return _localNotificationService.requestExactAlarmPermission();
  }

  Future<void> synchronize(AcademicTask task) async {
    await cancel(task.id);

    if (!_shouldSchedule(task)) {
      return;
    }

    final reminderAt = task.reminderAt!;

    await _localNotificationService.scheduleAcademicReminder(
      id: notificationIdForTask(task.id),
      title: 'Tarea próxima',
      body: task.title,
      scheduledAt: reminderAt,
      payload: {'type': 'academic_task', 'task_id': task.id},
    );
  }

  Future<void> cancel(String taskId) {
    return _localNotificationService.cancelNotification(
      notificationIdForTask(taskId),
    );
  }

  Future<void> restore(Iterable<AcademicTask> tasks) async {
    for (final task in tasks) {
      await synchronize(task);
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
