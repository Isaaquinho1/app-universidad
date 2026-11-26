/// A password recovery link belonging to Conecta ITT.
///
/// Parsing a link does not authenticate the user.
/// The token must be verified by Supabase.
class PasswordRecoveryLink {
  const PasswordRecoveryLink._({required this.tokenHash});

  static const scheme = 'mx.tecnm.tlalpan.conectaitt';
  static const host = 'password-recovery';

  final String tokenHash;

  /// Checks whether a URI targets the recovery flow.
  static bool isRecoveryDestination(Uri uri) {
    return uri.scheme == scheme &&
        uri.host == host &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        uri.path.isEmpty;
  }

  /// Validates the structure of a token-hash recovery link.
  ///
  /// Returns null for unsupported or malformed links.
  static PasswordRecoveryLink? tryParse(Uri uri) {
    if (!isRecoveryDestination(uri) || uri.hasFragment) {
      return null;
    }

    final parameters = uri.queryParametersAll;

    if (parameters.length != 2) {
      return null;
    }

    final types = parameters['type'];
    final tokens = parameters['token_hash'];

    if (types == null || types.length != 1 || types.single != 'recovery') {
      return null;
    }

    if (tokens == null || tokens.length != 1) {
      return null;
    }

    final tokenHash = tokens.single;

    if (tokenHash.isEmpty ||
        tokenHash.length > 512 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(tokenHash)) {
      return null;
    }

    return PasswordRecoveryLink._(tokenHash: tokenHash);
  }

  /// Never expose recovery credentials in logs.
  @override
  String toString() => 'PasswordRecoveryLink([REDACTED])';
}
