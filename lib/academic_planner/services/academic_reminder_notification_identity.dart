import 'dart:convert';

/// Genera identificadores locales asociados a una cuenta académica.
///
/// Esta utilidad no programa, modifica ni cancela notificaciones.
/// Los identificadores heredados deben tratarse por separado.
class AcademicReminderNotificationIdentity {
  const AcademicReminderNotificationIdentity._();

  static int forClassSession({
    required String userId,
    required String sessionId,
  }) {
    return 0x10000000 |
        (_hash(userId: userId, recordId: sessionId) & 0x0FFFFFFF);
  }

  static int forTask({required String userId, required String taskId}) {
    final value = _hash(userId: userId, recordId: taskId) & 0x0FFFFFFF;

    // El cero se reserva para evitar utilizarlo como identificador.
    return value == 0 ? 1 : value;
  }

  static int _hash({required String userId, required String recordId}) {
    if (userId.trim().isEmpty || recordId.trim().isEmpty) {
      throw ArgumentError(
        'El UID y el identificador académico no pueden estar vacíos.',
      );
    }

    const offsetBasis = 0x811C9DC5;
    const prime = 0x01000193;

    // Las longitudes separan inequívocamente los dos componentes.
    final input = '${userId.length}:$userId${recordId.length}:$recordId';

    var hash = offsetBasis;

    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFF;
    }

    return hash;
  }
}
