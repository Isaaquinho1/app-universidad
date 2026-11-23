import 'package:conecta_itt/institutional_profile/repositories/admin_academic_offerings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminAcademicOfferingsRepository', () {
    late List<Map<String, dynamic>> calls;
    late AdminAcademicOfferingsRepository repository;

    setUp(() {
      calls = <Map<String, dynamic>>[];

      repository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, parameters) async {
          calls.add({'name': name, 'parameters': parameters});
          return null;
        },
      );
    });

    test('activar grupo conserva identificador exacto', () async {
      await repository.setGroupActive(groupId: ' t21 ', active: true);

      expect(calls, hasLength(1));
      expect(calls.single['name'], 'admin_set_academic_group_active');
      expect(calls.single['parameters'], {
        'p_group_id': 't21',
        'p_active': true,
      });
    });

    test('desactivar grupo envia false', () async {
      await repository.setGroupActive(groupId: 'T21', active: false);

      expect(calls.single['parameters'], {
        'p_group_id': 'T21',
        'p_active': false,
      });
    });

    test('rechazar identificador de grupo vacio', () async {
      await expectLater(
        repository.setGroupActive(groupId: '   ', active: true),
        throwsArgumentError,
      );

      expect(calls, isEmpty);
    });

    test('habilitar oferta conserva identificador exacto', () async {
      await repository.setGroupOffering(
        periodCode: ' 2026-2 ',
        groupId: ' t21 ',
        isOffered: true,
      );

      expect(calls, hasLength(1));
      expect(calls.single['name'], 'admin_set_academic_group_offering');
      expect(calls.single['parameters'], {
        'p_period_code': '2026-2',
        'p_group_id': 't21',
        'p_is_offered': true,
      });
    });

    test('retirar oferta envia false', () async {
      await repository.setGroupOffering(
        periodCode: '2026-2',
        groupId: 'T21',
        isOffered: false,
      );

      expect(calls.single['parameters'], {
        'p_period_code': '2026-2',
        'p_group_id': 'T21',
        'p_is_offered': false,
      });
    });

    test('rechazar periodo vacio', () async {
      await expectLater(
        repository.setGroupOffering(
          periodCode: ' ',
          groupId: 'T21',
          isOffered: true,
        ),
        throwsArgumentError,
      );

      expect(calls, isEmpty);
    });

    test('rechazar grupo vacio en oferta', () async {
      await expectLater(
        repository.setGroupOffering(
          periodCode: '2026-2',
          groupId: ' ',
          isOffered: true,
        ),
        throwsArgumentError,
      );

      expect(calls, isEmpty);
    });

    test('propagar errores de la RPC administrativa', () async {
      final failingRepository = AdminAcademicOfferingsRepository.forTesting(
        invoke: (name, parameters) async {
          throw StateError('RPC rejected');
        },
      );

      await expectLater(
        failingRepository.setGroupActive(groupId: 'T21', active: true),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        failingRepository.setGroupOffering(
          periodCode: '2026-2',
          groupId: 'T21',
          isOffered: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
