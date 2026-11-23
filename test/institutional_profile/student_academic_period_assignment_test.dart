import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentAcademicPeriodAssignment', () {
    Map<String, dynamic> validRow() => {
      'academic_period_id': '11111111-1111-4111-8111-111111111111',
      'period_code': '2026-2',
      'period_name': 'Agosto - Diciembre 2026',
      'starts_on': '2026-08-01',
      'ends_on': '2026-12-31',
      'career_id': 'itic-2010-225',
      'semester': 2,
      'group_id': 'T21',
      'assigned_at': '2026-11-17T20:00:00Z',
      'updated_at': '2026-11-17T21:00:00Z',
    };

    test('interpreta correctamente un periodo completo', () {
      final assignment = StudentAcademicPeriodAssignment.fromSupabase(
        validRow(),
      );

      expect(assignment.periodCode, '2026-2');
      expect(assignment.careerId, 'itic-2010-225');
      expect(assignment.semester, 2);
      expect(assignment.groupId, 'T21');
      expect(assignment.hasGroup, isTrue);
      expect(assignment.startsOn, DateTime(2026, 8, 1));
      expect(assignment.endsOn, DateTime(2026, 12, 31));
      expect(assignment.assignedAt.isUtc, isTrue);
    });

    test('admite periodos sin grupo asignado', () {
      final row = validRow()..['group_id'] = null;

      final assignment = StudentAcademicPeriodAssignment.fromSupabase(row);

      expect(assignment.groupId, isNull);
      expect(assignment.hasGroup, isFalse);
    });

    test('admite fechas opcionales nulas', () {
      final row =
          validRow()
            ..['starts_on'] = null
            ..['ends_on'] = null;

      final assignment = StudentAcademicPeriodAssignment.fromSupabase(row);

      expect(assignment.startsOn, isNull);
      expect(assignment.endsOn, isNull);
    });

    test('rechaza semestres fuera del rango', () {
      final row = validRow()..['semester'] = 15;

      expect(
        () => StudentAcademicPeriodAssignment.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza un identificador de periodo vacio', () {
      final row = validRow()..['academic_period_id'] = '';

      expect(
        () => StudentAcademicPeriodAssignment.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza marcas de tiempo invalidas', () {
      final row = validRow()..['updated_at'] = 'fecha-invalida';

      expect(
        () => StudentAcademicPeriodAssignment.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza registros con grupo de tipo invalido', () {
      final row = validRow()..['group_id'] = 123;

      expect(
        () => StudentAcademicPeriodAssignment.fromSupabase(row),
        throwsFormatException,
      );
    });
  });
}
