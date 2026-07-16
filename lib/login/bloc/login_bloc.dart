import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:rtu_mirea_app/institutional_auth/institutional_auth.dart';
import 'package:user_repository/user_repository.dart';

part 'login_event.dart';
part 'login_state.dart';

/// Institutional email validation error.
enum EmailValidationError { invalid }

/// Institutional email input used by the login form.
class Email extends FormzInput<String, EmailValidationError> {
  const Email.pure() : super.pure('');

  const Email.dirty([super.value = '']) : super.dirty();

  String get normalizedValue => value.trim().toLowerCase();

  @override
  EmailValidationError? validator(String value) {
    final institutionalEmail = InstitutionalEmail.parse(value);

    return institutionalEmail.isValid ? null : EmailValidationError.invalid;
  }
}

/// Password validation error.
enum PasswordValidationError { invalid }

/// Password input used by the login form.
class Password extends FormzInput<String, PasswordValidationError> {
  const Password.pure() : super.pure('');

  const Password.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    return value.length >= 8 ? null : PasswordValidationError.invalid;
  }
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required UserRepository userRepository})
    : _userRepository = userRepository,
      super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityChanged>(_onPasswordVisibilityChanged);
    on<LoginSubmitted>(_onLoginSubmitted);

    // Se mantiene solo durante la migración de la interfaz anterior.
    on<SendEmailLinkSubmitted>(_onSendEmailLinkSubmitted);
  }

  final UserRepository _userRepository;

  void _onEmailChanged(LoginEmailChanged event, Emitter<LoginState> emit) {
    final email = Email.dirty(event.email);

    emit(
      state.copyWith(
        email: email,
        valid: Formz.validate([email, state.password]),
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginState> emit,
  ) {
    final password = Password.dirty(event.password);

    emit(
      state.copyWith(
        password: password,
        valid: Formz.validate([state.email, password]),
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onPasswordVisibilityChanged(
    LoginPasswordVisibilityChanged event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(passwordVisible: !state.passwordVisible));
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final email = Email.dirty(state.email.value);
    final password = Password.dirty(state.password.value);
    final valid = Formz.validate([email, password]);

    emit(
      state.copyWith(
        email: email,
        password: password,
        valid: valid,
        clearErrorMessage: true,
      ),
    );

    if (!valid) {
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    try {
      await _userRepository.signInWithPassword(
        email: email.normalizedValue,
        password: password.value,
      );

      emit(
        state.copyWith(
          status: FormzSubmissionStatus.success,
          clearErrorMessage: true,
        ),
      );
    } on SignInWithPasswordFailure catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: _authenticationErrorMessage(error),
        ),
      );
      addError(error, stackTrace);
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'No fue posible iniciar sesión. Inténtalo nuevamente.',
        ),
      );
      addError(error, stackTrace);
    }
  }

  Future<void> _onSendEmailLinkSubmitted(
    SendEmailLinkSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final email = Email.dirty(state.email.value);

    if (!email.isValid) {
      emit(state.copyWith(email: email, valid: false));
      return;
    }

    emit(
      state.copyWith(
        status: FormzSubmissionStatus.inProgress,
        clearErrorMessage: true,
      ),
    );

    try {
      await _userRepository.sendLoginEmailLink(email: email.normalizedValue);

      emit(state.copyWith(status: FormzSubmissionStatus.success));
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'No fue posible enviar el enlace de acceso.',
        ),
      );
      addError(error, stackTrace);
    }
  }

  static String _authenticationErrorMessage(SignInWithPasswordFailure failure) {
    final message = failure.error.toString().toLowerCase();

    if (message.contains('email not confirmed')) {
      return 'Debes confirmar tu correo institucional antes de iniciar sesión.';
    }

    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'El correo o la contraseña son incorrectos.';
    }

    if (message.contains('too many requests') ||
        message.contains('rate limit')) {
      return 'Se realizaron demasiados intentos. Espera unos minutos.';
    }

    return 'No fue posible iniciar sesión. Verifica tus datos.';
  }
}
