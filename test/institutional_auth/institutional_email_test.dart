import 'package:flutter_test/flutter_test.dart';
import 'package:conecta_itt/institutional_auth/models/institutional_email.dart';

void main() {
  group('InstitutionalEmail', () {
    test('identifica correctamente al estudiante', () {
      final email = InstitutionalEmail.parse('l191200037@tlalpan.tecnm.mx');

      expect(email.isValid, isTrue);
      expect(email.isStudent, isTrue);
      expect(email.controlNumber, '191200037');
    });

    test('acepta personal con nombre y apellido', () {
      final email = InstitutionalEmail.parse('maria.garcia@tlalpan.tecnm.mx');

      expect(email.isValid, isTrue);
      expect(email.isStaff, isTrue);
    });

    test('acepta personal con numeros', () {
      final email = InstitutionalEmail.parse('admin123@tlalpan.tecnm.mx');

      expect(email.isValid, isTrue);
      expect(email.isStaff, isTrue);
    });

    test('acepta correos segmentados de personal', () {
      final email = InstitutionalEmail.parse(
        'prueba.visual.abc123@tlalpan.tecnm.mx',
      );

      expect(email.isValid, isTrue);
      expect(email.isStaff, isTrue);
    });

    test('acepta personal del TecNM', () {
      final email = InstitutionalEmail.parse('personal123@tecnm.mx');

      expect(email.isValid, isTrue);
      expect(email.isStaff, isTrue);
    });

    test('rechaza dominios externos', () {
      final email = InstitutionalEmail.parse('personal@gmail.com');

      expect(email.isValid, isFalse);
    });

    test('rechaza separadores consecutivos', () {
      final email = InstitutionalEmail.parse('maria..garcia@tlalpan.tecnm.mx');

      expect(email.isValid, isFalse);
    });

    test('normaliza mayusculas y espacios', () {
      final email = InstitutionalEmail.parse(
        '  MARIA.GARCIA@TLALPAN.TECNM.MX  ',
      );

      expect(email.isValid, isTrue);
      expect(email.value, 'maria.garcia@tlalpan.tecnm.mx');
    });
  });
}
