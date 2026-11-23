import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> sample() => {
    'academic_period_id': 'period-uuid',
    'period_code': '2027-1',
    'period_name': 'Enero-Junio 2027',
    'period_starts_on': '2027-01-25',
    'period_ends_on': '2027-06-04',
    'group_id': 'T21',
    'group_name': 'T21',
    'career_id': 'itic-2010-225',
    'semester': 2,
    'group_active': false,
    'offering_registered': false,
    'is_offered': false,
    'offering_updated_at': null,
  };

  group('AdminAcademicGroupOffering', () {

    // PRE-BETA 191: preservar identificadores institucionales exactos.
    for (final groupId in ['t91', 'T91']) {
      test(
        'PRE-BETA 191 - conserva identificador $groupId',
        () {
          final row = Map<String, dynamic>.from(sample());
          row['group_id'] = ' $groupId ';

          final offering =
              AdminAcademicGroupOffering.fromSupabase(row);

          expect(offering.groupId, groupId);
        },
      );
    }

    test('interpreta una oferta sin configurar', () {
      final offering = AdminAcademicGroupOffering.fromSupabase(sample());

      expect(offering.periodCode, '2027-1');
      expect(offering.groupId, 'T21');
      expect(offering.semester, 2);
      expect(offering.groupActive, isFalse);
      expect(offering.isUnconfigured, isTrue);
      expect(offering.isEnabled, isFalse);
      expect(offering.isDisabled, isFalse);
    });

    test('interpreta una oferta habilitada', () {
      final row =
          sample()
            ..['offering_registered'] = true
            ..['is_offered'] = true
            ..['offering_updated_at'] = '2026-11-17T20:00:00Z';

      final offering = AdminAcademicGroupOffering.fromSupabase(row);

      expect(offering.isEnabled, isTrue);
      expect(offering.isUnconfigured, isFalse);
      expect(offering.offeringUpdatedAt, isNotNull);
    });

    test('distingue una oferta desactivada', () {
      final row =
          sample()
            ..['offering_registered'] = true
            ..['is_offered'] = false;

      final offering = AdminAcademicGroupOffering.fromSupabase(row);

      expect(offering.isDisabled, isTrue);
      expect(offering.isUnconfigured, isFalse);
    });

    test('admite grupos sin semestre', () {
      final row = sample()..['semester'] = null;

      final offering = AdminAcademicGroupOffering.fromSupabase(row);

      expect(offering.semester, isNull);
    });

    test('rechaza una oferta inconsistente', () {
      final row = sample()..['is_offered'] = true;

      expect(
        () => AdminAcademicGroupOffering.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza campos obligatorios ausentes', () {
      final row = sample()..remove('group_id');

      expect(
        () => AdminAcademicGroupOffering.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza fechas invalidas', () {
      final row = sample()..['period_starts_on'] = 'invalid';

      expect(
        () => AdminAcademicGroupOffering.fromSupabase(row),
        throwsFormatException,
      );
    });

    test('rechaza semestres fuera de rango', () {
      final row = sample()..['semester'] = 15;

      expect(
        () => AdminAcademicGroupOffering.fromSupabase(row),
        throwsFormatException,
      );
    });
  });
}
