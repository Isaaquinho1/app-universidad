import 'package:conecta_itt/login/services/password_recovery_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'mx.tecnm.tlalpan.conectaitt://password-recovery';

  group('PasswordRecoveryLink', () {
    test('accepts a valid recovery link', () {
      final link = PasswordRecoveryLink.tryParse(
        Uri.parse('$base?token_hash=test-token&type=recovery'),
      );

      expect(link, isNotNull);
      expect(link!.tokenHash, 'test-token');
    });

    test('rejects another scheme', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse(
            'other://password-recovery'
            '?token_hash=test&type=recovery',
          ),
        ),
        isNull,
      );
    });

    test('rejects another destination', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse(
            'mx.tecnm.tlalpan.conectaitt://login-callback'
            '?token_hash=test&type=recovery',
          ),
        ),
        isNull,
      );
    });

    test('rejects a missing token', () {
      expect(
        PasswordRecoveryLink.tryParse(Uri.parse('$base?type=recovery')),
        isNull,
      );
    });

    test('rejects an empty token', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=&type=recovery'),
        ),
        isNull,
      );
    });

    test('rejects an incorrect recovery type', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=test&type=signup'),
        ),
        isNull,
      );
    });

    test('rejects duplicate tokens', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=one&token_hash=two&type=recovery'),
        ),
        isNull,
      );
    });

    test('rejects duplicate recovery types', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=test&type=recovery&type=signup'),
        ),
        isNull,
      );
    });

    test('rejects unexpected parameters', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=test&type=recovery&extra=value'),
        ),
        isNull,
      );
    });

    test('rejects fragment credentials', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=test&type=recovery#access_token=test'),
        ),
        isNull,
      );
    });

    test('rejects invalid token characters', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base?token_hash=invalid%20token&type=recovery'),
        ),
        isNull,
      );
    });

    test('rejects unexpected paths', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base/other?token_hash=test&type=recovery'),
        ),
        isNull,
      );
    });

    test('rejects explicit ports', () {
      expect(
        PasswordRecoveryLink.tryParse(
          Uri.parse('$base:8080?token_hash=test&type=recovery'),
        ),
        isNull,
      );
    });

    test('redacts the token from diagnostic output', () {
      final link = PasswordRecoveryLink.tryParse(
        Uri.parse('$base?token_hash=secret-test&type=recovery'),
      );

      expect(link.toString(), isNot(contains('secret-test')));
    });
  });
}
