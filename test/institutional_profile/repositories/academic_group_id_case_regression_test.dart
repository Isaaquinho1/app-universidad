import 'package:conecta_itt/institutional_profile/repositories/admin_academic_offerings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-BETA 188 - Identificadores exactos', () {
    for (final groupId in ['t91', 'T91']) {
      test('activacion conserva exactamente $groupId', () async {
        final calls = <Map<String, dynamic>>[];

        final repository = AdminAcademicOfferingsRepository.forTesting(
          invoke: (name, parameters) async {
            calls.add({
              'name': name,
              'parameters': parameters,
            });
            return null;
          },
        );

        await repository.setGroupActive(
          groupId: ' $groupId ',
          active: true,
        );

        expect(calls, hasLength(1));
        expect(
          calls.single['name'],
          'admin_set_academic_group_active',
        );
        expect(
          calls.single['parameters'],
          {
            'p_group_id': groupId,
            'p_active': true,
          },
        );
      });

      test('oferta conserva exactamente $groupId', () async {
        final calls = <Map<String, dynamic>>[];

        final repository = AdminAcademicOfferingsRepository.forTesting(
          invoke: (name, parameters) async {
            calls.add({
              'name': name,
              'parameters': parameters,
            });
            return null;
          },
        );

        await repository.setGroupOffering(
          periodCode: ' 2026-2 ',
          groupId: ' $groupId ',
          isOffered: true,
        );

        expect(calls, hasLength(1));
        expect(
          calls.single['name'],
          'admin_set_academic_group_offering',
        );
        expect(
          calls.single['parameters'],
          {
            'p_period_code': '2026-2',
            'p_group_id': groupId,
            'p_is_offered': true,
          },
        );
      });
    }
  });
}
