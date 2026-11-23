import 'package:conecta_itt/institutional_profile/constants/institutional_careers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catálogo institucional TecNM Tlalpan', () {
    test('contiene exactamente cuatro carreras', () {
      expect(InstitutionalCareers.values, hasLength(4));
    });

    test('conserva las tres carreras anteriores', () {
      final ids =
          InstitutionalCareers.values.map((career) => career.id).toSet();

      expect(ids, contains('itic-2010-225'));
      expect(ids, contains('igem-2009-201'));
      expect(ids, contains('ielc-2010-211'));
    });

    test('incluye Licenciatura en Administración', () {
      expect(InstitutionalCareers.ladm.id, 'ladm-2010-234');
      expect(InstitutionalCareers.ladm.name, 'Licenciatura en Administración');
      expect(
        InstitutionalCareers.labelFor('ladm-2010-234'),
        'Licenciatura en Administración',
      );
    });

    test('no contiene identificadores duplicados', () {
      final ids =
          InstitutionalCareers.values.map((career) => career.id).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('todos los identificadores están normalizados', () {
      for (final career in InstitutionalCareers.values) {
        expect(career.id, career.id.toLowerCase());
        expect(career.id.trim(), career.id);
      }
    });

    test('un identificador desconocido se conserva', () {
      expect(
        InstitutionalCareers.labelFor('carrera-desconocida'),
        'carrera-desconocida',
      );
    });
  });
}
