import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/database/academic_database_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicDatabase scope', () {
    test('conserva el nombre de la base heredada', () {
      expect(
        AcademicDatabase.instance.databaseName,
        AcademicDatabaseIdentity.legacyDatabaseName,
      );
    });

    test('crea nombres independientes por usuario', () {
      final first = AcademicDatabase.forUser('student-a');
      final second = AcademicDatabase.forUser('student-b');

      expect(first.databaseName, isNot(second.databaseName));
    });

    test('mantiene el mismo nombre para una misma cuenta', () {
      final first = AcademicDatabase.forUser('student-a');
      final second = AcademicDatabase.forUser('student-a');

      expect(first.databaseName, second.databaseName);
    });

    test('no asigna la base heredada a una cuenta nueva', () {
      final scoped = AcademicDatabase.forUser('student-a');

      expect(
        scoped.databaseName,
        isNot(AcademicDatabase.instance.databaseName),
      );
    });

    test('rechaza una cuenta sin identificador', () {
      expect(() => AcademicDatabase.forUser(''), throwsArgumentError);
    });
  });
}
