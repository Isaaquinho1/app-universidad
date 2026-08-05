part of 'login_bloc.dart';

class LoginState extends Equatable {
  const LoginState({
    this.email = const Email.pure(),
    this.password = const Password.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.valid = false,
    this.passwordVisible = false,
    this.errorMessage,
    this.biometricType = BiometricLoginType.none,
    this.biometricAvailable = false,
    this.biometricCredentialsSaved = false,
    this.biometricAuthenticating = false,
    this.biometricEnrollmentPending = false,
    this.biometricMessage,
  });

  final Email email;
  final Password password;
  final FormzSubmissionStatus status;
  final bool valid;
  final bool passwordVisible;
  final String? errorMessage;

  final BiometricLoginType biometricType;
  final bool biometricAvailable;
  final bool biometricCredentialsSaved;
  final bool biometricAuthenticating;
  final bool biometricEnrollmentPending;
  final String? biometricMessage;

  bool get canUseBiometricLogin =>
      biometricAvailable &&
      biometricCredentialsSaved &&
      !biometricAuthenticating &&
      !status.isInProgress;

  LoginState copyWith({
    Email? email,
    Password? password,
    FormzSubmissionStatus? status,
    bool? valid,
    bool? passwordVisible,
    String? errorMessage,
    bool clearErrorMessage = false,
    BiometricLoginType? biometricType,
    bool? biometricAvailable,
    bool? biometricCredentialsSaved,
    bool? biometricAuthenticating,
    bool? biometricEnrollmentPending,
    String? biometricMessage,
    bool clearBiometricMessage = false,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      valid: valid ?? this.valid,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      biometricType: biometricType ?? this.biometricType,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricCredentialsSaved:
          biometricCredentialsSaved ?? this.biometricCredentialsSaved,
      biometricAuthenticating:
          biometricAuthenticating ?? this.biometricAuthenticating,
      biometricEnrollmentPending:
          biometricEnrollmentPending ?? this.biometricEnrollmentPending,
      biometricMessage:
          clearBiometricMessage
              ? null
              : biometricMessage ?? this.biometricMessage,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    status,
    valid,
    passwordVisible,
    errorMessage,
    biometricType,
    biometricAvailable,
    biometricCredentialsSaved,
    biometricAuthenticating,
    biometricEnrollmentPending,
    biometricMessage,
  ];
}
