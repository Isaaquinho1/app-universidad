import 'package:auth_client/auth_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:token_storage/token_storage.dart';

/// Supabase implementation of [AuthenticationClient].
class SupabaseAuthenticationClient implements AuthenticationClient {
  /// Creates a [SupabaseAuthenticationClient].
  SupabaseAuthenticationClient({
    required TokenStorage tokenStorage,
    required GoTrueClient supabaseAuth,
  }) : _tokenStorage = tokenStorage,
       _supabaseAuth = supabaseAuth {
    user.listen(_onUserChanged);
  }

  final TokenStorage _tokenStorage;
  final GoTrueClient _supabaseAuth;

  @override
  Stream<AuthenticationUser> get user {
    return _supabaseAuth.onAuthStateChange.map((data) {
      final session = data.session;

      if (session == null) {
        return AuthenticationUser.anonymous;
      }

      return session.user.toAuthenticationUser;
    });
  }

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabaseAuth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
        data: data,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _supabaseAuth.signInWithPassword(email: email, password: password);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignInWithPasswordFailure(error), stackTrace);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabaseAuth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SendPasswordResetEmailFailure(error),
        stackTrace,
      );
    }
  }

  @override
  Future<void> resendSignUpConfirmation({
    required String email,
    String? emailRedirectTo,
  }) async {
    try {
      await _supabaseAuth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ResendSignUpConfirmationFailure(error),
        stackTrace,
      );
    }
  }

  @override
  Future<void> sendLoginEmailLink({
    required String email,
    required String appPackageName,
  }) async {
    try {
      await _supabaseAuth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        emailRedirectTo: '$appPackageName://login-callback',
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SendLoginEmailLinkFailure(error), stackTrace);
    }
  }

  Future<void> _verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _supabaseAuth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithEmailLinkFailure(error), stackTrace);
    }
  }

  @override
  bool isLogInWithEmailLink({required String emailLink}) {
    return emailLink.contains('://login-callback');
  }

  @override
  Future<void> logInWithEmailLink({
    required String email,
    required String emailLink,
  }) {
    final uri = Uri.parse(emailLink);
    final token = uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      throw LogInWithEmailLinkFailure(
        ArgumentError('The authentication link does not contain a token.'),
      );
    }

    return _verifyOtp(email: email, token: token);
  }

  @override
  Future<void> logOut() async {
    try {
      await _supabaseAuth.signOut();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogOutFailure(error), stackTrace);
    }
  }

  @override
  Future<void> deleteAccount() async {
    throw DeleteAccountFailure(
      UnsupportedError(
        'Deleting an authenticated user requires a trusted backend.',
      ),
    );
  }

  Future<void> _onUserChanged(AuthenticationUser user) async {
    if (user.isAnonymous) {
      await _tokenStorage.clearToken();
      return;
    }

    await _tokenStorage.saveToken(user.id);
  }
}

extension on User {
  AuthenticationUser get toAuthenticationUser {
    return AuthenticationUser(
      id: id,
      email: email,
      name: userMetadata?['name'] as String?,
      photo: userMetadata?['avatar_url'] as String?,
      isNewUser: createdAt == lastSignInAt,
    );
  }
}
