import 'package:conecta_itt/login/services/password_recovery_session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Coordinates verified password recovery operations.
///
/// Normal authentication must be suspended while recovery is active.
/// The application must route all recovery operations through one
/// instance of this service.
/// A password rejected by the authentication server.
class PasswordRecoveryRejectedException implements Exception {
  const PasswordRecoveryRejectedException(this.code);

  final String code;
}

class SupabasePasswordRecoveryService {
  SupabasePasswordRecoveryService({
    required GoTrueClient auth,
    required PasswordRecoverySessionController controller,
  }) : _auth = auth,
       _controller = controller;

  final GoTrueClient _auth;
  final PasswordRecoverySessionController _controller;

  bool _busy = false;

  bool get isBusy => _busy;

  RecoverySessionIdentity? _currentIdentity() {
    final session = _auth.currentSession;

    if (session == null) {
      return null;
    }

    return _identityFromSession(session);
  }

  RecoverySessionIdentity _identityFromSession(Session session) {
    return RecoverySessionIdentity.fromAccessToken(
      userId: session.user.id,
      accessToken: session.accessToken,
    );
  }

  bool _sameSession(
    RecoverySessionIdentity? first,
    RecoverySessionIdentity? second,
  ) {
    return first != null &&
        second != null &&
        first.userId == second.userId &&
        first.sessionId == second.sessionId;
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) {
      throw StateError('A password recovery operation is already in progress.');
    }

    _busy = true;

    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  /// Reconciles an interrupted recovery after application startup.
  ///
  /// Recovery sessions are intentionally not persisted.
  /// This operation only affects the independent recovery client.
  Future<void> initializeRecoveryContext() {
    return _exclusive(() async {
      final status = await getStatus();

      if (status == PasswordRecoverySessionStatus.signedOut ||
          status == PasswordRecoverySessionStatus.recovery) {
        return;
      }

      await _invalidateAndClear();
    });
  }

  /// Returns the current classification without granting access.
  Future<PasswordRecoverySessionStatus> getStatus() async {
    try {
      return await _controller.classify(_currentIdentity());
    } catch (_) {
      return PasswordRecoverySessionStatus.blocked;
    }
  }

  /// Requests a password recovery email using the isolated client.
  ///
  /// Requesting an email does not establish a recovery session.
  Future<void> requestRecoveryEmail({required String email}) {
    final normalizedEmail = email.trim().toLowerCase();

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      throw ArgumentError('Introduce un correo electrónico válido.');
    }

    return _exclusive(() async {
      final status = await getStatus();

      if (status != PasswordRecoverySessionStatus.signedOut) {
        throw StateError('Finish or cancel the previous recovery first.');
      }

      await _auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: 'mx.tecnm.tlalpan.conectaitt://password-recovery',
      );
    });
  }

  /// Verifies a recovery code delivered to the user's email.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();

    if (normalizedEmail.isEmpty || normalizedCode.isEmpty) {
      throw ArgumentError('Email and recovery code are required.');
    }

    return _exclusive(
      () => _verify(
        () => _auth.verifyOTP(
          email: normalizedEmail,
          token: normalizedCode,
          type: OtpType.recovery,
        ),
      ),
    );
  }

  /// Verifies a recovery token hash received through a trusted link.
  ///
  /// The caller must validate the link scheme and destination.
  Future<void> verifyRecoveryTokenHash({required String tokenHash}) {
    if (tokenHash.trim().isEmpty) {
      throw ArgumentError('Recovery token hash is required.');
    }

    return _exclusive(
      () => _verify(
        () => _auth.verifyOTP(
          tokenHash: tokenHash.trim(),
          type: OtpType.recovery,
        ),
      ),
    );
  }

  Future<void> _verify(Future<AuthResponse> Function() verify) async {
    // Never silently replace an existing authenticated account.
    if (_auth.currentSession != null) {
      throw StateError('Sign out before starting password recovery.');
    }

    // Persist the recovery marker BEFORE verifying the token.
    await _controller.beginVerification();

    try {
      if (_auth.currentSession != null) {
        throw StateError('Authentication changed during recovery.');
      }

      final response = await verify();
      final session = response.session;

      if (session == null) {
        throw StateError('Recovery verification returned no session.');
      }

      final verifiedIdentity = _identityFromSession(session);

      if (!_sameSession(verifiedIdentity, _currentIdentity())) {
        throw StateError('The verified recovery session is no longer active.');
      }

      await _controller.bindVerifiedSession(verifiedIdentity);

      if (!_sameSession(verifiedIdentity, _currentIdentity())) {
        throw StateError('Authentication changed while binding recovery.');
      }
    } catch (_) {
      // Do not clear the pending marker if a session exists.
      // A partially established session must remain blocked.
      if (_auth.currentSession == null) {
        await _controller.clearAfterSignOut(currentSession: null);
      }

      rethrow;
    }
  }

  /// Updates the password only for a matching recovery session.
  ///
  /// All other authentication operations must remain suspended.
  Future<void> completeRecovery({
    required String password,
    required String confirmation,
  }) {
    if (password.length < 8) {
      throw ArgumentError('La contraseña debe tener al menos 8 caracteres.');
    }

    if (password != confirmation) {
      throw ArgumentError('Las contraseñas no coinciden.');
    }

    return _exclusive(() async {
      final identity = _currentIdentity();

      if (identity == null || !await _controller.canUpdatePassword(identity)) {
        throw StateError('No verified password recovery session exists.');
      }

      if (!_sameSession(identity, _currentIdentity())) {
        throw StateError('Authentication changed during recovery.');
      }

      try {
        await _auth.updateUser(UserAttributes(password: password));
      } on AuthException catch (error) {
        final code = error.code;

        if ((code == 'same_password' || code == 'weak_password') &&
            _sameSession(identity, _currentIdentity()) &&
            await _controller.canUpdatePassword(identity) &&
            _sameSession(identity, _currentIdentity())) {
          throw PasswordRecoveryRejectedException(code!);
        }

        rethrow;
      }

      if (!_sameSession(identity, _currentIdentity())) {
        throw StateError('Authentication changed after password update.');
      }

      await _invalidateAndClear();
    });
  }

  /// Cancels recovery and invalidates its local session.
  Future<void> cancelRecovery() {
    return _exclusive(() async {
      final status = await getStatus();

      if (status == PasswordRecoverySessionStatus.normal) {
        throw StateError('The current session is not a recovery session.');
      }

      await _invalidateAndClear();
    });
  }

  Future<void> _invalidateAndClear() async {
    if (_auth.currentSession != null) {
      await _auth.signOut(scope: SignOutScope.local);
    }

    // Never remove the recovery marker with an active session.
    await _controller.clearAfterSignOut(currentSession: _currentIdentity());
  }
}
