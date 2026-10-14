import 'dart:convert';

/// Genera un nombre de base SQLite independiente por cuenta.
///
/// No modifica ni elimina la base académica heredada.
class AcademicDatabaseIdentity {
  const AcademicDatabaseIdentity._();

  static const legacyDatabaseName = 'conecta_itt_academic.db';

  static String databaseNameForUser(String userId) {
    final normalizedId = userId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Se requiere un identificador de usuario válido.',
      );
    }

    final encodedId = base64Url
        .encode(utf8.encode(normalizedId))
        .replaceAll('=', '');

    return 'conecta_itt_academic_$encodedId.db';
  }
}
