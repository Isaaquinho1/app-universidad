import 'package:conecta_itt/login/services/authentication_link_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheme = 'mx.tecnm.tlalpan.conectaitt';

  group('AuthenticationLinkPolicy', () {
    AuthenticationLinkKind classify(String value) =>
        AuthenticationLinkPolicy.classify(Uri.parse(value));

    test('recognizes token hash recovery', () {
      expect(
        classify(
          '$scheme://password-recovery'
          '?token_hash=test-token&type=recovery',
        ),
        AuthenticationLinkKind.recovery,
      );
    });

    test('rejects legacy recovery code callback', () {
      expect(
        classify('$scheme://password-recovery?code=test-code'),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('rejects legacy recovery session tokens', () {
      expect(
        classify(
          '$scheme://password-recovery'
          '#access_token=test&refresh_token=test&type=recovery',
        ),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('rejects recovery without credentials', () {
      expect(
        classify('$scheme://password-recovery'),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('rejects duplicate recovery token parameters', () {
      expect(
        classify(
          '$scheme://password-recovery'
          '?token_hash=one&token_hash=two&type=recovery',
        ),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('classifies email confirmation callback', () {
      expect(
        classify('$scheme://email-confirmation?code=test-code'),
        AuthenticationLinkKind.emailConfirmation,
      );
    });

    test('classifies login callback', () {
      expect(
        classify('$scheme://login-callback?token=test-token'),
        AuthenticationLinkKind.loginCallback,
      );
    });

    test('rejects recovery disguised as email confirmation', () {
      expect(
        classify(
          '$scheme://email-confirmation'
          '?code=test-code&type=recovery',
        ),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('rejects recovery disguised as login callback', () {
      expect(
        classify(
          '$scheme://login-callback'
          '#access_token=test&type=recovery',
        ),
        AuthenticationLinkKind.unsupportedRecovery,
      );
    });

    test('rejects duplicate ordinary callback parameters', () {
      expect(
        classify('$scheme://email-confirmation?code=one&code=two'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('rejects parameters repeated across query and fragment', () {
      expect(
        classify('$scheme://login-callback?token=one#token=two'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('ignores unknown destinations', () {
      expect(
        classify('$scheme://unknown?code=test'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('ignores external schemes', () {
      expect(
        classify('other://password-recovery?token_hash=test'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('ignores legacy application scheme', () {
      expect(
        classify('com.ituniversity.app://login-callback?token=test'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('rejects unexpected paths', () {
      expect(
        classify('$scheme://email-confirmation/other?code=test'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('rejects explicit ports', () {
      expect(
        classify('$scheme://login-callback:8080?token=test'),
        AuthenticationLinkKind.ignored,
      );
    });

    test('rejects user information in callback', () {
      expect(
        classify('$scheme://student@login-callback?token=test'),
        AuthenticationLinkKind.ignored,
      );
    });
  });
}
