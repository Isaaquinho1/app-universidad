import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:conecta_itt/login/services/biometric_login_service.dart';
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
  LoginBloc({
    required UserRepository userRepository,
    required BiometricLoginService biometricLoginService,
  }) : _userRepository = userRepository,
       _biometricLoginService = biometricLoginService,
       super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityChanged>(_onPasswordVisibilityChanged);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginBiometricAvailabilityRequested>(_onBiometricAvailabilityRequested);
    on<LoginBiometricSubmitted>(_onBiometricSubmitted);
    on<LoginBiometricEnrollmentAccepted>(_onBiometricEnrollmentAccepted);
    on<LoginBiometricEnrollmentDeclined>(_onBiometricEnrollmentDeclined);
    on<LoginBiometricEnrollmentHandled>(_onBiometricEnrollmentHandled);

    // Se mantiene solo durante la migración de la interfaz anterior.
    on<SendEmailLinkSubmitted>(_onSendEmailLinkSubmitted);
  }

  final UserRepository _userRepository;
  final BiometricLoginService _biometricLoginService;

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

      final biometricType = await _biometricLoginService.getAvailableType();

      final biometricAvailable = biometricType != BiometricLoginType.none;

      final alreadyConfigured =
          biometricAvailable &&
          await _biometricLoginService.hasSavedCredentials();

      final shouldOfferEnrollment = biometricAvailable && !alreadyConfigured;

      emit(
        state.copyWith(
          status:
              shouldOfferEnrollment
                  ? FormzSubmissionStatus.initial
                  : FormzSubmissionStatus.success,
          biometricType: biometricType,
          biometricAvailable: biometricAvailable,
          biometricCredentialsSaved: alreadyConfigured,
          biometricEnrollmentPending: shouldOfferEnrollment,
          clearErrorMessage: true,
          clearBiometricMessage: true,
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

  Future<void> _onBiometricAvailabilityRequested(
    LoginBiometricAvailabilityRequested event,
    Emitter<LoginState> emit,
  ) async {
    final biometricType = await _biometricLoginService.getAvailableType();
    final hasSavedCredentials =
        biometricType != BiometricLoginType.none &&
        await _biometricLoginService.hasSavedCredentials();

    emit(
      state.copyWith(
        biometricType: biometricType,
        biometricAvailable: biometricType != BiometricLoginType.none,
        biometricCredentialsSaved: hasSavedCredentials,
        biometricAuthenticating: false,
        clearBiometricMessage: true,
      ),
    );

    if (hasSavedCredentials) {
      add(const LoginBiometricSubmitted());
    }
  }

  Future<void> _onBiometricSubmitted(
    LoginBiometricSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.canUseBiometricLogin) {
      return;
    }

    emit(
      state.copyWith(
        biometricAuthenticating: true,
        clearErrorMessage: true,
        clearBiometricMessage: true,
      ),
    );

    try {
      final authenticated = await _biometricLoginService.authenticate();

      if (!authenticated) {
        emit(
          state.copyWith(
            biometricAuthenticating: false,
            biometricMessage: 'No se completó la autenticación biométrica.',
          ),
        );
        return;
      }

      final credentials = await _biometricLoginService.readCredentials();

      if (credentials == null) {
        emit(
          state.copyWith(
            biometricAuthenticating: false,
            biometricCredentialsSaved: false,
            biometricMessage:
                'No hay credenciales biométricas guardadas en este dispositivo.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: FormzSubmissionStatus.inProgress,
          biometricAuthenticating: true,
          clearErrorMessage: true,
          clearBiometricMessage: true,
        ),
      );

      await _userRepository.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );

      emit(
        state.copyWith(
          email: Email.dirty(credentials.email),
          password: const Password.pure(),
          status: FormzSubmissionStatus.success,
          valid: false,
          biometricAuthenticating: false,
          biometricEnrollmentPending: false,
          clearErrorMessage: true,
          clearBiometricMessage: true,
        ),
      );
    } on SignInWithPasswordFailure catch (error, stackTrace) {
      await _biometricLoginService.clearCredentials();

      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          biometricAuthenticating: false,
          biometricCredentialsSaved: false,
          biometricMessage:
              'El acceso biométrico dejó de ser válido. '
              'Inicia sesión nuevamente con tu correo y contraseña.',
          errorMessage: _authenticationErrorMessage(error),
        ),
      );

      addError(error, stackTrace);
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          biometricAuthenticating: false,
          biometricMessage: 'No fue posible iniciar sesión con biometría.',
        ),
      );

      addError(error, stackTrace);
    }
  }

  Future<void> _onBiometricEnrollmentAccepted(
    LoginBiometricEnrollmentAccepted event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.biometricEnrollmentPending ||
        !state.biometricAvailable ||
        state.email.normalizedValue.isEmpty ||
        state.password.value.isEmpty) {
      emit(state.copyWith(biometricEnrollmentPending: false));
      return;
    }

    emit(
      state.copyWith(
        biometricAuthenticating: true,
        clearBiometricMessage: true,
      ),
    );

    final authenticated = await _biometricLoginService.authenticate();

    if (!authenticated) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.success,
          biometricAuthenticating: false,
          biometricEnrollmentPending: false,
          biometricMessage: 'No se activó el acceso biométrico.',
        ),
      );
      return;
    }

    try {
      await _biometricLoginService.saveCredentials(
        email: state.email.normalizedValue,
        password: state.password.value,
      );

      emit(
        state.copyWith(
          status: FormzSubmissionStatus.success,
          biometricAuthenticating: false,
          biometricCredentialsSaved: true,
          biometricEnrollmentPending: false,
          biometricMessage:
              'El acceso biométrico quedó activado en este dispositivo.',
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.success,
          biometricAuthenticating: false,
          biometricEnrollmentPending: false,
          biometricMessage: 'No fue posible guardar el acceso biométrico.',
        ),
      );

      addError(error, stackTrace);
    }
  }

  void _onBiometricEnrollmentDeclined(
    LoginBiometricEnrollmentDeclined event,
    Emitter<LoginState> emit,
  ) {
    emit(
      state.copyWith(
        status: FormzSubmissionStatus.success,
        biometricEnrollmentPending: false,
      ),
    );
  }

  void _onBiometricEnrollmentHandled(
    LoginBiometricEnrollmentHandled event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(biometricEnrollmentPending: false));
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
