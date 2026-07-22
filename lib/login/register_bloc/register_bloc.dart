import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:user_repository/user_repository.dart';

part 'register_event.dart';
part 'register_state.dart';

enum RegisterEmailValidationError { invalid }

class RegisterEmail extends FormzInput<String, RegisterEmailValidationError> {
  const RegisterEmail.pure() : super.pure('');

  const RegisterEmail.dirty([super.value = '']) : super.dirty();

  String get normalizedValue => value.trim().toLowerCase();

  InstitutionalEmail get institutionalEmail => InstitutionalEmail.parse(value);

  @override
  RegisterEmailValidationError? validator(String value) {
    return InstitutionalEmail.parse(value).isValid
        ? null
        : RegisterEmailValidationError.invalid;
  }
}

enum RegisterPasswordValidationError {
  tooShort,
  missingUppercase,
  missingLowercase,
  missingNumber,
}

class RegisterPassword
    extends FormzInput<String, RegisterPasswordValidationError> {
  const RegisterPassword.pure() : super.pure('');

  const RegisterPassword.dirty([super.value = '']) : super.dirty();

  @override
  RegisterPasswordValidationError? validator(String value) {
    if (value.length < 8) {
      return RegisterPasswordValidationError.tooShort;
    }

    if (!RegExp('[A-Z]').hasMatch(value)) {
      return RegisterPasswordValidationError.missingUppercase;
    }

    if (!RegExp('[a-z]').hasMatch(value)) {
      return RegisterPasswordValidationError.missingLowercase;
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return RegisterPasswordValidationError.missingNumber;
    }

    return null;
  }
}

enum RegisterPasswordConfirmationValidationError { empty, mismatch }

class RegisterPasswordConfirmation
    extends FormzInput<String, RegisterPasswordConfirmationValidationError> {
  const RegisterPasswordConfirmation.pure({this.password = ''})
    : super.pure('');

  const RegisterPasswordConfirmation.dirty({
    required this.password,
    String value = '',
  }) : super.dirty(value);

  final String password;

  @override
  RegisterPasswordConfirmationValidationError? validator(String value) {
    if (value.isEmpty) {
      return RegisterPasswordConfirmationValidationError.empty;
    }

    if (value != password) {
      return RegisterPasswordConfirmationValidationError.mismatch;
    }

    return null;
  }
}

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required UserRepository userRepository})
    : _userRepository = userRepository,
      super(const RegisterState()) {
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterPasswordConfirmationChanged>(_onPasswordConfirmationChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  final UserRepository _userRepository;

  void _onEmailChanged(
    RegisterEmailChanged event,
    Emitter<RegisterState> emit,
  ) {
    final email = RegisterEmail.dirty(event.email);
    final institutionalEmail = email.institutionalEmail;

    emit(
      state.copyWith(
        email: email,
        emailType: institutionalEmail.type,
        controlNumber: institutionalEmail.controlNumber,
        clearControlNumber: institutionalEmail.controlNumber == null,
        valid: _validate(
          email: email,
          password: state.password,
          passwordConfirmation: state.passwordConfirmation,
        ),
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onPasswordChanged(
    RegisterPasswordChanged event,
    Emitter<RegisterState> emit,
  ) {
    final password = RegisterPassword.dirty(event.password);
    final confirmation = RegisterPasswordConfirmation.dirty(
      password: password.value,
      value: state.passwordConfirmation.value,
    );

    emit(
      state.copyWith(
        password: password,
        passwordConfirmation: confirmation,
        valid: _validate(
          email: state.email,
          password: password,
          passwordConfirmation: confirmation,
        ),
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onPasswordConfirmationChanged(
    RegisterPasswordConfirmationChanged event,
    Emitter<RegisterState> emit,
  ) {
    final confirmation = RegisterPasswordConfirmation.dirty(
      password: state.password.value,
      value: event.passwordConfirmation,
    );

    emit(
      state.copyWith(
        passwordConfirmation: confirmation,
        valid: _validate(
          email: state.email,
          password: state.password,
          passwordConfirmation: confirmation,
        ),
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    final email = RegisterEmail.dirty(state.email.value);
    final password = RegisterPassword.dirty(state.password.value);
    final passwordConfirmation = RegisterPasswordConfirmation.dirty(
      password: password.value,
      value: state.passwordConfirmation.value,
    );

    final valid = _validate(
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );

    emit(
      state.copyWith(
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        valid: valid,
        clearErrorMessage: true,
      ),
    );

    if (!valid) {
      return;
    }

    final institutionalEmail = email.institutionalEmail;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    try {
      await _userRepository.signUpWithPassword(
        email: email.normalizedValue,
        password: password.value,
        data: {
          'institutionalEmailType': institutionalEmail.type.name,
          if (institutionalEmail.controlNumber != null)
            'controlNumber': institutionalEmail.controlNumber,
          'staffApprovalPending': institutionalEmail.type.isStaff,
        },
      );

      emit(
        state.copyWith(
          status: FormzSubmissionStatus.success,
          clearErrorMessage: true,
        ),
      );
    } on SignUpWithPasswordFailure catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: _registrationErrorMessage(error),
        ),
      );
      addError(error, stackTrace);
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'No fue posible crear la cuenta. Inténtalo nuevamente.',
        ),
      );
      addError(error, stackTrace);
    }
  }

  static bool _validate({
    required RegisterEmail email,
    required RegisterPassword password,
    required RegisterPasswordConfirmation passwordConfirmation,
  }) {
    return Formz.validate([email, password, passwordConfirmation]);
  }

  static String _registrationErrorMessage(SignUpWithPasswordFailure failure) {
    final message = failure.error.toString().toLowerCase();

    if (message.contains('already registered') ||
        message.contains('user already exists')) {
      return 'Este correo institucional ya está registrado.';
    }

    if (message.contains('password')) {
      return 'La contraseña no cumple los requisitos de seguridad.';
    }

    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Se realizaron demasiados intentos. Espera unos minutos.';
    }

    return 'No fue posible crear la cuenta institucional.';
  }
}
