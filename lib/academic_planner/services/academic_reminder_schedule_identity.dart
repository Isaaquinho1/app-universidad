import 'dart:convert';

/// Identifica la configuración deseada de una alarma académica.
///
/// La firma NO acredita propiedad: antes de reutilizar una alarma
/// debe verificarse su UID, tipo, registro e ID determinista.
class AcademicReminderScheduleIdentity {
  static const version = 1;
  static const versionKey = 'schedule_version';
  static const signatureKey = 'schedule_signature';

  static String forTask({
    required String title,
    required DateTime scheduledAt,
  }) {
    return jsonEncode([
      'task',
      title,
      scheduledAt.toUtc().millisecondsSinceEpoch,
    ]);
  }

  static String forClassSession({
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    return jsonEncode(['class_session', body, weekday, hour, minute]);
  }

  /// Solo acepta payloads actuales con una firma idéntica.
  ///
  /// Un payload antiguo, incompleto o malformado no es verificable.
  static bool matches({
    required String? payload,
    required String expectedSignature,
  }) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      return decoded[versionKey] == version &&
          decoded[signatureKey] == expectedSignature;
    } on FormatException {
      return false;
    }
  }
}
