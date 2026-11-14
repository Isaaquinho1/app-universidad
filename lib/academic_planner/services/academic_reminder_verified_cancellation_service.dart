import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';

/// Cancela exclusivamente alarmas académicas cuya identidad y
/// propietario estén confirmados por el payload persistido.
class AcademicReminderVerifiedCancellationService {
  AcademicReminderVerifiedCancellationService({
    LocalNotificationService? localNotificationService,
  }) : _notifications =
           localNotificationService ?? LocalNotificationService.instance;

  final LocalNotificationService _notifications;

  /// Devuelve true únicamente si se identificó y canceló la alarma.
  ///
  /// Si la consulta falla, propaga el error sin cancelar nada.
  Future<bool> cancelOwned({
    required String userId,
    required String recordId,
    required bool isTask,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();

    final id =
        isTask
            ? AcademicReminderNotificationIdentity.forTask(
              userId: userId,
              taskId: recordId,
            )
            : AcademicReminderNotificationIdentity.forClassSession(
              userId: userId,
              sessionId: recordId,
            );

    final pending = await _notifications.pendingNotificationRequests();

    ensureCurrent?.call();

    final occupants = pending.where((request) => request.id == id).toList();

    // La cancelación por ID afectaría a un identificador ambiguo.
    // Rechazarlo incluso cuando una solicitud acredite propiedad.
    if (occupants.length > 1) {
      throw StateError('No se puede cancelar un ID académico ambiguo: $id');
    }

    final matches = occupants.any(
      (request) => isOwnedNotification(
        id: request.id,
        payload: request.payload,
        userId: userId,
        recordId: recordId,
        isTask: isTask,
      ),
    );

    if (!matches) {
      return false;
    }

    ensureCurrent?.call();
    await _notifications.cancelNotification(id);
    return true;
  }

  /// Verifica UID, registro, tipo y algoritmo determinista.
  ///
  /// Nunca considera como propia una alarma heredada sin UID.
  /// Evita sobrescribir otra notificación que utilice el mismo ID.
  ///
  /// Una consulta fallida o una identidad incompatible impiden programar.
  Future<void> ensureSlotAvailable({
    required String userId,
    required String recordId,
    required bool isTask,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();

    final id =
        isTask
            ? AcademicReminderNotificationIdentity.forTask(
              userId: userId,
              taskId: recordId,
            )
            : AcademicReminderNotificationIdentity.forClassSession(
              userId: userId,
              sessionId: recordId,
            );

    final pending = await _notifications.pendingNotificationRequests();

    ensureCurrent?.call();

    final occupants = pending.where((request) => request.id == id).toList();

    // Si el plugin reporta más de una solicitud para el mismo ID,
    // no podemos garantizar una actualización inequívoca.
    if (occupants.length > 1) {
      throw StateError(
        'ID académico ambiguo: $id (${occupants.length} solicitudes)',
      );
    }

    for (final request in occupants) {
      if (!isOwnedNotification(
        id: request.id,
        payload: request.payload,
        userId: userId,
        recordId: recordId,
        isTask: isTask,
      )) {
        throw StateError('ID de notificación ocupado por otra identidad: $id');
      }
    }

    ensureCurrent?.call();
  }

  /// Comprueba tanto la propiedad académica como la configuración.
  ///
  /// No modifica ni cancela notificaciones. Una firma coincidente
  /// nunca sustituye la validación del propietario y del ID.
  static bool isMatchingSchedule({
    required int id,
    required String? payload,
    required String userId,
    required String recordId,
    required bool isTask,
    required String expectedSignature,
  }) {
    return isOwnedNotification(
          id: id,
          payload: payload,
          userId: userId,
          recordId: recordId,
          isTask: isTask,
        ) &&
        AcademicReminderScheduleIdentity.matches(
          payload: payload,
          expectedSignature: expectedSignature,
        );
  }

  static bool isOwnedNotification({
    required int id,
    required String? payload,
    required String userId,
    required String recordId,
    required bool isTask,
  }) {
    if (userId.trim().isEmpty ||
        recordId.trim().isEmpty ||
        payload == null ||
        payload.isEmpty) {
      return false;
    }

    Object? decoded;

    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return false;
    }

    if (decoded is! Map) {
      return false;
    }

    final expectedType = isTask ? 'academic_task' : 'class_session';
    final recordKey = isTask ? 'task_id' : 'session_id';

    if (decoded['type'] != expectedType ||
        decoded['user_id'] != userId ||
        decoded[recordKey] != recordId) {
      return false;
    }

    if (!isTask) {
      final subjectId = decoded['subject_id'];
      if (subjectId is! String || subjectId.trim().isEmpty) {
        return false;
      }
    }

    final expectedId =
        isTask
            ? AcademicReminderNotificationIdentity.forTask(
              userId: userId,
              taskId: recordId,
            )
            : AcademicReminderNotificationIdentity.forClassSession(
              userId: userId,
              sessionId: recordId,
            );

    return id == expectedId;
  }
}
