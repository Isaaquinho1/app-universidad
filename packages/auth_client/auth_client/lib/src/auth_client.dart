import 'dart:async';

import 'package:auth_client/auth_client.dart';

/// {@template authentication_exception}
/// Base exception thrown by the authentication client.
/// {@endtemplate}
abstract class AuthenticationException implements Exception {
  /// {@macro authentication_exception}
  const AuthenticationException(this.error);

  /// Original error caught by the authentication provider.
  final Object error;
}

/// Thrown when registration with email and password fails.
class SignUpWithPasswordFailure extends AuthenticationException {
  /// Creates a [SignUpWithPasswordFailure].
  const SignUpWithPasswordFailure(super.error);
  @override
  String toString() {
    return error.toString();
  }
}

/// Thrown when sign-in with email and password fails.
class SignInWithPasswordFailure extends AuthenticationException {
  /// Creates a [SignInWithPasswordFailure].
  const SignInWithPasswordFailure(super.error);
}

/// Thrown when sending a password recovery email fails.
class SendPasswordResetEmailFailure extends AuthenticationException {
  /// Creates a [SendPasswordResetEmailFailure].
  const SendPasswordResetEmailFailure(super.error);
}

/// Thrown when resending a signup confirmation email fails.
class ResendSignUpConfirmationFailure extends AuthenticationException {
  /// Creates a [ResendSignUpConfirmationFailure].
  const ResendSignUpConfirmationFailure(super.error);
}

/// Thrown when sending a login email link fails.
///
/// Kept temporarily while the legacy Magic Link flow is migrated.
class SendLoginEmailLinkFailure extends AuthenticationException {
  /// Creates a [SendLoginEmailLinkFailure].
  const SendLoginEmailLinkFailure(super.error);
}

/// Thrown when validating a login email link fails.
///
/// Kept temporarily while the legacy Magic Link flow is migrated.
class IsLogInWithEmailLinkFailure extends AuthenticationException {
  /// Creates an [IsLogInWithEmailLinkFailure].
  const IsLogInWithEmailLinkFailure(super.error);
}

/// Thrown when signing in with an email link fails.
///
/// Kept temporarily while the legacy Magic Link flow is migrated.
class LogInWithEmailLinkFailure extends AuthenticationException {
  /// Creates a [LogInWithEmailLinkFailure].
  const LogInWithEmailLinkFailure(super.error);
}

/// Thrown when logout fails.
class LogOutFailure extends AuthenticationException {
  /// Creates a [LogOutFailure].
  const LogOutFailure(super.error);
}

/// Thrown when account deletion fails.
class DeleteAccountFailure extends AuthenticationException {
  /// Creates a [DeleteAccountFailure].
  const DeleteAccountFailure(super.error);
}

/// Generic authentication client contract.
abstract class AuthenticationClient {
  /// Emits the current authenticated user.
  ///
  /// Emits [AuthenticationUser.anonymous] when no session exists.
  Stream<AuthenticationUser> get user;

  /// Registers a user using email and password.
  ///
  /// [emailRedirectTo] is used by the email confirmation link.
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
  });

  /// Signs in an existing user using email and password.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Sends a password recovery email.
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  });

  /// Resends the signup confirmation email.
  Future<void> resendSignUpConfirmation({
    required String email,
    String? emailRedirectTo,
  });

  /// Sends a legacy Magic Link.
  ///
  /// This method will be removed after the new authentication UI is complete.
  Future<void> sendLoginEmailLink({
    required String email,
    required String appPackageName,
  });

  /// Checks whether an incoming URI is a legacy Magic Link.
  bool isLogInWithEmailLink({required String emailLink});

  /// Completes legacy Magic Link authentication.
  Future<void> logInWithEmailLink({
    required String email,
    required String emailLink,
  });

  /// Signs out the current user.
  Future<void> logOut();

  /// Deletes the current user account.
  Future<void> deleteAccount();
}
