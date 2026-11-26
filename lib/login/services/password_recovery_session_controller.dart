import 'dart:convert';

import 'package:conecta_itt/login/services/password_recovery_storage.dart';

/// Local identity of a session already established by Supabase.
///
/// Decoding a JWT does not verify its signature. This identity must
/// only be constructed from a session provided by the trusted SDK.
class RecoverySessionIdentity {
  RecoverySessionIdentity({required this.userId, required this.sessionId}) {
    if (userId.trim().isEmpty || sessionId.trim().isEmpty) {
      throw ArgumentError('Session identifiers cannot be empty.');
    }
  }

  final String userId;
  final String sessionId;

  factory RecoverySessionIdentity.fromAccessToken({
    required String userId,
    required String accessToken,
  }) {
    final parts = accessToken.split('.');

    if (parts.length != 3) {
      throw const FormatException('Invalid JWT structure.');
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );

    final claims = jsonDecode(payload);

    if (claims is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT payload.');
    }

    final subject = claims['sub'];
    final sessionId = claims['session_id'];

    if (subject != userId || sessionId is! String || sessionId.trim().isEmpty) {
      throw const FormatException('Invalid session identity.');
    }

    return RecoverySessionIdentity(userId: userId, sessionId: sessionId);
  }
}

/// Local classification of an authentication session.
enum PasswordRecoverySessionStatus {
  signedOut,
  normal,
  pending,
  recovery,
  blocked,
}

/// Coordinates the persistent password recovery context.
///
/// This controller does not authenticate users or verify JWT signatures.
/// The caller must obtain sessions from Supabase and serialize auth actions.
class PasswordRecoverySessionController {
  PasswordRecoverySessionController({required PasswordRecoveryStorage storage})
    : _storage = storage;

  final PasswordRecoveryStorage _storage;

  /// Must complete before the SDK establishes a recovery session.
  Future<void> beginVerification() async {
    final context = await _storage.read();

    if (context != null) {
      throw StateError('A recovery context already exists.');
    }

    await _storage.markPending();
  }

  /// Binds a session only after successful recovery verification.
  ///
  /// The caller must confirm the recovery result through the SDK.
  Future<void> bindVerifiedSession(RecoverySessionIdentity identity) async {
    final context = await _storage.read();

    if (context == null || !context.isPending) {
      throw StateError('No pending recovery verification.');
    }

    await _storage.bindSession(
      userId: identity.userId,
      sessionId: identity.sessionId,
    );
  }

  /// Classifies the current session without silently clearing context.
  Future<PasswordRecoverySessionStatus> classify(
    RecoverySessionIdentity? identity,
  ) async {
    try {
      final context = await _storage.read();

      if (context == null) {
        return identity == null
            ? PasswordRecoverySessionStatus.signedOut
            : PasswordRecoverySessionStatus.normal;
      }

      if (context.isPending) {
        return identity == null
            ? PasswordRecoverySessionStatus.pending
            : PasswordRecoverySessionStatus.blocked;
      }

      if (identity == null) {
        return PasswordRecoverySessionStatus.blocked;
      }

      if (context.matchesSession(
        userId: identity.userId,
        sessionId: identity.sessionId,
      )) {
        return PasswordRecoverySessionStatus.recovery;
      }

      return PasswordRecoverySessionStatus.blocked;
    } catch (_) {
      return PasswordRecoverySessionStatus.blocked;
    }
  }

  /// Checks whether the local context matches the recovery session.
  ///
  /// This check is not a substitute for server-side authorization.
  Future<bool> canUpdatePassword(RecoverySessionIdentity identity) async {
    return await classify(identity) == PasswordRecoverySessionStatus.recovery;
  }

  /// Clears context only after the caller confirms local sign-out.
  Future<void> clearAfterSignOut({
    required RecoverySessionIdentity? currentSession,
  }) async {
    if (currentSession != null) {
      throw StateError('Cannot clear recovery with an active session.');
    }

    await _storage.clear();
  }
}
