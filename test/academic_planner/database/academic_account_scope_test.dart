import 'package:conecta_itt/academic_planner/database/academic_database_identity.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicAccountScope', () {
    test('asocia la base con el identificador del usuario', () {
      final scope = AcademicAccountScope.forUser('student-a');

      expect(scope.userId, 'student-a');
      expect(
        scope.database.databaseName,
        AcademicDatabaseIdentity.databaseNameForUser('student-a'),
      );
    });

    test('mantiene bases independientes entre cuentas', () {
      final first = AcademicAccountScope.forUser('student-a');
      final second = AcademicAccountScope.forUser('student-b');

      expect(first.database.databaseName, isNot(second.database.databaseName));
    });

    test('no utiliza la base académica heredada', () {
      final scope = AcademicAccountScope.forUser('student-a');

      expect(
        scope.database.databaseName,
        isNot(AcademicDatabaseIdentity.legacyDatabaseName),
      );
    });

    test('reutiliza los repositorios de una misma cuenta', () {
      final scope = AcademicAccountScope.forUser('student-a');

      expect(identical(scope.subjects, scope.subjects), isTrue);
      expect(identical(scope.tasks, scope.tasks), isTrue);
      expect(identical(scope.subtasks, scope.subtasks), isTrue);
      expect(identical(scope.categories, scope.categories), isTrue);
      expect(identical(scope.sessions, scope.sessions), isTrue);
      expect(identical(scope.dailySchedule, scope.dailySchedule), isTrue);
      expect(identical(scope.weeklySchedule, scope.weeklySchedule), isTrue);
    });

    test('rechaza un identificador vacío', () {
      expect(() => AcademicAccountScope.forUser('  '), throwsArgumentError);
    });
  });
}
