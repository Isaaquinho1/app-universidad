part of 'register_bloc.dart';

class RegisterState extends Equatable {
  const RegisterState({
    this.email = const RegisterEmail.pure(),
    this.password = const RegisterPassword.pure(),
    this.passwordConfirmation = const RegisterPasswordConfirmation.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.valid = false,
    this.emailType = InstitutionalEmailType.invalid,
    this.controlNumber,
    this.errorMessage,
  });

  final RegisterEmail email;
  final RegisterPassword password;
  final RegisterPasswordConfirmation passwordConfirmation;
  final FormzSubmissionStatus status;
  final bool valid;
  final InstitutionalEmailType emailType;
  final String? controlNumber;
  final String? errorMessage;

  RegisterState copyWith({
    RegisterEmail? email,
    RegisterPassword? password,
    RegisterPasswordConfirmation? passwordConfirmation,
    FormzSubmissionStatus? status,
    bool? valid,
    InstitutionalEmailType? emailType,
    String? controlNumber,
    bool clearControlNumber = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RegisterState(
      email: email ?? this.email,
      password: password ?? this.password,
      passwordConfirmation: passwordConfirmation ?? this.passwordConfirmation,
      status: status ?? this.status,
      valid: valid ?? this.valid,
      emailType: emailType ?? this.emailType,
      controlNumber:
          clearControlNumber ? null : controlNumber ?? this.controlNumber,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    passwordConfirmation,
    status,
    valid,
    emailType,
    controlNumber,
    errorMessage,
  ];
}
