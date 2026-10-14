import 'package:conecta_itt/academic_planner/database/academic_database_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicDatabaseIdentity', () {
    test('genera un nombre estable para el mismo usuario', () {
      final first = AcademicDatabaseIdentity.databaseNameForUser('user-123');

      final second = AcademicDatabaseIdentity.databaseNameForUser('user-123');

      expect(first, second);
    });

    test('separa los nombres de usuarios diferentes', () {
      final first = AcademicDatabaseIdentity.databaseNameForUser('user-123');

      final second = AcademicDatabaseIdentity.databaseNameForUser('user-456');

      expect(first, isNot(second));
    });

    test('no reutiliza el nombre de la base heredada', () {
      final name = AcademicDatabaseIdentity.databaseNameForUser('user-123');

      expect(name, isNot(AcademicDatabaseIdentity.legacyDatabaseName));
    });

    test('rechaza identificadores vacíos', () {
      expect(
        () => AcademicDatabaseIdentity.databaseNameForUser('  '),
        throwsArgumentError,
      );
    });

    test('produce un nombre de archivo sin separadores de ruta', () {
      final name = AcademicDatabaseIdentity.databaseNameForUser('user/123');

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(r'\')));
      expect(name, endsWith('.db'));
    });
  });
}
