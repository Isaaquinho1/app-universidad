import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';

import 'package:conecta_itt/app/services/local_notification_service.dart';

/// Identifica alarmas académicas que deben retirarse al reconciliar
/// una cuenta. No modifica datos académicos ni notificaciones FCM.
class AcademicReminderPendingCleanupService {
  AcademicReminderPendingCleanupService({
    LocalNotificationService? localNotificationService,
  }) : _notifications =
           localNotificationService ?? LocalNotificationService.instance;

  final LocalNotificationService _notifications;

  /// Este método debe ejecutarse dentro de una operación serializada
  /// y solamente cuando la sesión autenticada haya sido verificada.
  Future<int> cancelForeignAndLegacy({
    required String activeUserId,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();

    if (activeUserId.trim().isEmpty) {
      throw ArgumentError.value(activeUserId, 'activeUserId');
    }

    final pending = await _notifications.pendingNotificationRequests();
    ensureCurrent?.call();

    var cancelled = 0;

    for (final request in pending) {
      ensureCurrent?.call();
      if (!shouldCancel(
        id: request.id,
        payload: request.payload,
        activeUserId: activeUserId,
      )) {
        continue;
      }

      ensureCurrent?.call();
      await _notifications.cancelNotification(request.id);
      ensureCurrent?.call();
      cancelled++;
    }

    ensureCurrent?.call();
    return cancelled;
  }

  /// Regla pura, independiente del plugin, para facilitar
  /// las pruebas de seguridad y compatibilidad.
  static bool shouldCancel({
    required int id,
    required String? payload,
    required String activeUserId,
  }) {
    if (activeUserId.trim().isEmpty || payload == null || payload.isEmpty) {
      return false;
    }

    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      data = decoded;
    } on FormatException {
      return false;
    }

    final type = data['type'];
    final owner = data['user_id'];

    final bool isLegacy;
    final bool isCurrentRange;

    if (type == 'academic_task') {
      if (!_hasId(data['task_id'])) {
        return false;
      }

      isCurrentRange = id >= 1 && id <= 0x0FFFFFFF;
      isLegacy = id >= 0x40000000 && id <= 0x7FFFFFFF;
    } else if (type == 'class_session') {
      if (!_hasId(data['session_id']) || !_hasId(data['subject_id'])) {
        return false;
      }

      isCurrentRange = id >= 0x10000000 && id <= 0x1FFFFFFF;

      isLegacy = id >= 0x20000000 && id <= 0x3FFFFFFF;
    } else {
      // Comunicados institucionales y otros tipos:
      // nunca se cancelan desde este servicio.
      return false;
    }

    if (!isCurrentRange && !isLegacy) {
      return false;
    }

    // Las alarmas heredadas no incluyen una identidad de cuenta
    // verificable. Se conservan hasta una migración controlada.
    if (isLegacy) {
      return false;
    }

    // En el esquema nuevo exigimos propietario e identidad
    // determinista coincidente; el rango no basta.
    if (owner is! String || owner.trim().isEmpty) {
      return false;
    }

    final expectedId =
        type == 'academic_task'
            ? AcademicReminderNotificationIdentity.forTask(
              userId: owner,
              taskId: data['task_id'] as String,
            )
            : AcademicReminderNotificationIdentity.forClassSession(
              userId: owner,
              sessionId: data['session_id'] as String,
            );

    return id == expectedId && owner != activeUserId;
  }

  static bool _hasId(Object? value) =>
      value is String && value.trim().isNotEmpty;
}
