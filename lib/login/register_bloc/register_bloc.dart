import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
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
  RegisterBloc({
    required UserRepository userRepository,
    required AcademicCatalogRepository academicCatalogRepository,
  }) : _userRepository = userRepository,
       _academicCatalogRepository = academicCatalogRepository,
       super(const RegisterState()) {
    on<RegisterFullNameChanged>(_onFullNameChanged);
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterCareerChanged>(_onCareerChanged);
    on<RegisterSemesterChanged>(_onSemesterChanged);
    on<RegisterGroupChanged>(_onGroupChanged);
    on<RegisterTermsAcceptanceChanged>(_onTermsAcceptanceChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterPasswordConfirmationChanged>(_onPasswordConfirmationChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  final UserRepository _userRepository;
  final AcademicCatalogRepository _academicCatalogRepository;

  void _onFullNameChanged(
    RegisterFullNameChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        fullName: event.fullName,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onEmailChanged(
    RegisterEmailChanged event,
    Emitter<RegisterState> emit,
  ) {
    final email = RegisterEmail.dirty(event.email);
    final institutionalEmail = email.institutionalEmail;
    final changingToNonStudent = !institutionalEmail.type.isStudent;

    _emitValidated(
      emit,
      state.copyWith(
        email: email,
        emailType: institutionalEmail.type,
        controlNumber: institutionalEmail.controlNumber,
        clearControlNumber: institutionalEmail.controlNumber == null,
        clearCareerId: changingToNonStudent,
        clearSemester: changingToNonStudent,
        clearGroupId: true,
        availableGroups:
            changingToNonStudent ? const [] : state.availableGroups,
        groupsStatus:
            changingToNonStudent
                ? AcademicGroupsStatus.initial
                : state.groupsStatus,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onCareerChanged(
    RegisterCareerChanged event,
    Emitter<RegisterState> emit,
  ) async {
    final next = state.copyWith(
      careerId: event.careerId,
      clearCareerId: event.careerId == null,
      clearGroupId: true,
      availableGroups: const [],
      groupsStatus: AcademicGroupsStatus.initial,
      status: FormzSubmissionStatus.initial,
      clearErrorMessage: true,
    );

    _emitValidated(emit, next);

    await _loadGroupsIfReady(emit);
  }

  Future<void> _onSemesterChanged(
    RegisterSemesterChanged event,
    Emitter<RegisterState> emit,
  ) async {
    final next = state.copyWith(
      semester: event.semester,
      clearSemester: event.semester == null,
      clearGroupId: true,
      availableGroups: const [],
      groupsStatus: AcademicGroupsStatus.initial,
      status: FormzSubmissionStatus.initial,
      clearErrorMessage: true,
    );

    _emitValidated(emit, next);

    await _loadGroupsIfReady(emit);
  }

  void _onGroupChanged(
    RegisterGroupChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        groupId: event.groupId,
        clearGroupId: event.groupId == null,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onTermsAcceptanceChanged(
    RegisterTermsAcceptanceChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        termsAccepted: event.accepted,
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

    _emitValidated(
      emit,
      state.copyWith(
        password: password,
        passwordConfirmation: confirmation,
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

    _emitValidated(
      emit,
      state.copyWith(
        passwordConfirmation: confirmation,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _loadGroupsIfReady(Emitter<RegisterState> emit) async {
    final current = state;

    if (!current.isStudent ||
        current.careerId == null ||
        current.semester == null) {
      return;
    }

    emit(
      current.copyWith(
        groupsStatus: AcademicGroupsStatus.loading,
        availableGroups: const [],
        clearGroupId: true,
        valid: _validateState(
          current.copyWith(
            groupsStatus: AcademicGroupsStatus.loading,
            availableGroups: const [],
            clearGroupId: true,
          ),
        ),
      ),
    );

    try {
      final groups = await _academicCatalogRepository.fetchGroups(
        careerId: state.careerId!,
        semester: state.semester!,
      );

      final next = state.copyWith(
        availableGroups: groups,
        groupsStatus: AcademicGroupsStatus.success,
        clearGroupId: true,
      );

      _emitValidated(emit, next);
    } catch (error, stackTrace) {
      final next = state.copyWith(
        availableGroups: const [],
        groupsStatus: AcademicGroupsStatus.failure,
        clearGroupId: true,
        errorMessage:
            'No fue posible consultar los grupos académicos disponibles.',
      );

      _emitValidated(emit, next);
      addError(error, stackTrace);
    }
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    final email = RegisterEmail.dirty(state.email.value);
    final password = RegisterPassword.dirty(state.password.value);
    final confirmation = RegisterPasswordConfirmation.dirty(
      password: password.value,
      value: state.passwordConfirmation.value,
    );

    final submittedState = state.copyWith(
      email: email,
      password: password,
      passwordConfirmation: confirmation,
      clearErrorMessage: true,
    );

    final valid = _validateState(submittedState);

    emit(submittedState.copyWith(valid: valid));

    if (!valid) {
      return;
    }

    final institutionalEmail = email.institutionalEmail;
    final isStudent = institutionalEmail.type.isStudent;
    final hasGroupCatalog = submittedState.availableGroups.isNotEmpty;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    try {
      await _userRepository.signUpWithPassword(
        email: email.normalizedValue,
        password: password.value,
        data: {
          'display_name': submittedState.fullName.trim(),
          'institutionalEmailType': institutionalEmail.type.name,
          'termsAccepted': true,
          'termsAcceptedAt': DateTime.now().toUtc().toIso8601String(),
          if (institutionalEmail.controlNumber != null)
            'controlNumber': institutionalEmail.controlNumber,
          if (isStudent) ...{
            'careerId': submittedState.careerId,
            'semester': submittedState.semester,
            if (hasGroupCatalog) 'groupId': submittedState.groupId,
            'profileCompleted': hasGroupCatalog,
            'staffApprovalPending': false,
          },
          if (institutionalEmail.type.isStaff) ...{
            'profileCompleted': true,
            'staffApprovalPending': true,
          },
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

  void _emitValidated(Emitter<RegisterState> emit, RegisterState next) {
    emit(next.copyWith(valid: _validateState(next)));
  }

  static bool _validateState(RegisterState state) {
    final fullNameValid = state.fullName.trim().length >= 3;

    final credentialsValid = Formz.validate([
      state.email,
      state.password,
      state.passwordConfirmation,
    ]);

    final commonValid =
        fullNameValid &&
        credentialsValid &&
        state.termsAccepted &&
        state.emailType.isValid;

    if (!commonValid) {
      return false;
    }

    if (state.isStaff) {
      return true;
    }

    if (!state.isStudent || state.careerId == null || state.semester == null) {
      return false;
    }

    if (state.groupsStatus == AcademicGroupsStatus.loading ||
        state.groupsStatus == AcademicGroupsStatus.failure) {
      return false;
    }

    if (state.availableGroups.isNotEmpty) {
      return state.groupId != null;
    }

    return state.groupsStatus == AcademicGroupsStatus.success;
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

    if (message.contains('career')) {
      return 'La carrera seleccionada no está disponible.';
    }

    if (message.contains('academic group') || message.contains('group')) {
      return 'El grupo académico seleccionado no es válido.';
    }

    if (message.contains('semester')) {
      return 'El semestre seleccionado no es válido.';
    }

    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Se realizaron demasiados intentos. Espera unos minutos.';
    }

    return 'No fue posible crear la cuenta institucional.';
  }
}
