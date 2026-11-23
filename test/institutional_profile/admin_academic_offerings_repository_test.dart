import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> sampleOffering() => {
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

  group('AdminAcademicOfferingsRepository', () {
    test('consulta ofertas con los filtros correctos', () async {
      String? calledFunction;
      Map<String, dynamic>? calledParams;

      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          calledFunction = name;
          calledParams = params;
          return [sampleOffering()];
        },
      );

      final offerings = await repository.fetchOfferings(
        periodCode: ' 2027-1 ',
        careerId: ' ITIC-2010-225 ',
        semester: 2,
      );

      expect(calledFunction, 'admin_get_academic_group_offerings');
      expect(calledParams, {
        'p_period_code': '2027-1',
        'p_career_id': 'itic-2010-225',
        'p_semester': 2,
      });
      expect(offerings, hasLength(1));
      expect(offerings.single.groupId, 'T21');
    });

    test('consulta todos los grupos sin filtros', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          expect(params['p_career_id'], isNull);
          expect(params['p_semester'], isNull);
          return <Map<String, dynamic>>[];
        },
      );

      final result = await repository.fetchOfferings(periodCode: '2026-2');

      expect(result, isEmpty);
    });

    test('rechaza periodos vacios', () async {
      var invoked = false;

      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          invoked = true;
          return [];
        },
      );

      await expectLater(
        repository.fetchOfferings(periodCode: ' '),
        throwsArgumentError,
      );

      expect(invoked, isFalse);
    });

    test('rechaza semestres invalidos', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async => [],
      );

      await expectLater(
        repository.fetchOfferings(periodCode: '2027-1', semester: 15),
        throwsArgumentError,
      );
    });

    test('rechaza respuestas con estructura incorrecta', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async => {'bad': true},
      );

      await expectLater(
        repository.fetchOfferings(periodCode: '2027-1'),
        throwsFormatException,
      );
    });

    test('rechaza filas invalidas', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async => ['invalid-row'],
      );

      await expectLater(
        repository.fetchOfferings(periodCode: '2027-1'),
        throwsFormatException,
      );
    });

    test('crea grupo con parametros normalizados', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          expect(name, 'admin_create_academic_group');
          expect(params, {
            'p_career_id': 'itic-2010-225',
            'p_semester': 2,
            'p_parallel': 2,
          });
          return 'T22';
        },
      );

      final id = await repository.createGroup(
        careerId: ' ITIC-2010-225 ',
        semester: 2,
        parallel: 2,
      );

      expect(id, 'T22');
    });

    test('rechaza paralelos invalidos', () async {
      var invoked = false;

      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          invoked = true;
          return 'T20';
        },
      );

      await expectLater(
        repository.createGroup(
          careerId: 'itic-2010-225',
          semester: 2,
          parallel: 0,
        ),
        throwsArgumentError,
      );

      expect(invoked, isFalse);
    });

    test('habilita una oferta conservando el grupo', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          expect(name, 'admin_set_academic_group_offering');
          expect(params, {
            'p_period_code': '2027-1',
            'p_group_id': 't21',
            'p_is_offered': true,
          });
          return null;
        },
      );

      await repository.setGroupOffering(
        periodCode: '2027-1',
        groupId: ' t21 ',
        isOffered: true,
      );
    });

    test('deshabilita una oferta sin eliminar grupos', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          expect(params['p_is_offered'], isFalse);
          return null;
        },
      );

      await repository.setGroupOffering(
        periodCode: '2027-1',
        groupId: 'T21',
        isOffered: false,
      );
    });

    test('propaga errores del servidor', () async {
      final repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, params) async {
          throw StateError('Server denied access');
        },
      );

      await expectLater(
        repository.fetchOfferings(periodCode: '2027-1'),
        throwsStateError,
      );
    });
  });
}
