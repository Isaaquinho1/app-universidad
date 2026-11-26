import 'package:conecta_itt/login/services/password_recovery_link.dart';

/// Classification of incoming authentication links.
///
/// Classification alone does not establish or authorize a session.
enum AuthenticationLinkKind {
  recovery,
  unsupportedRecovery,
  emailConfirmation,
  loginCallback,
  ignored,
}

/// Separates recovery links from ordinary authentication callbacks.
abstract final class AuthenticationLinkPolicy {
  static const _scheme = 'mx.tecnm.tlalpan.conectaitt';

  /// Classifies a URI without consuming its credentials.
  static AuthenticationLinkKind classify(Uri uri) {
    if (uri.scheme != _scheme ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.isNotEmpty) {
      return AuthenticationLinkKind.ignored;
    }

    final query = uri.queryParametersAll;

    Map<String, List<String>> fragment;

    try {
      fragment = Uri(query: uri.fragment).queryParametersAll;
    } on FormatException {
      return AuthenticationLinkKind.ignored;
    }

    if (uri.host == PasswordRecoveryLink.host) {
      return PasswordRecoveryLink.tryParse(uri) != null
          ? AuthenticationLinkKind.recovery
          : AuthenticationLinkKind.unsupportedRecovery;
    }

    // Never forward an explicitly identified recovery callback
    // to the institutional authentication client.
    if ((query['type']?.contains('recovery') ?? false) ||
        (fragment['type']?.contains('recovery') ?? false)) {
      return AuthenticationLinkKind.unsupportedRecovery;
    }

    // Reject ambiguous authentication parameters.
    if (query.values.any((values) => values.length != 1) ||
        fragment.values.any((values) => values.length != 1) ||
        query.keys.any(fragment.containsKey)) {
      return AuthenticationLinkKind.ignored;
    }

    return switch (uri.host) {
      'email-confirmation' => AuthenticationLinkKind.emailConfirmation,
      'login-callback' => AuthenticationLinkKind.loginCallback,
      _ => AuthenticationLinkKind.ignored,
    };
  }
}
