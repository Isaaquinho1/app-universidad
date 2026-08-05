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
    required LegalDocumentRepository legalDocumentRepository,
  }) : _userRepository = userRepository,
       _academicCatalogRepository = academicCatalogRepository,
       _legalDocumentRepository = legalDocumentRepository,
       super(const RegisterState()) {
    on<RegisterGivenNamesChanged>(_onGivenNamesChanged);
    on<RegisterFirstSurnameChanged>(_onFirstSurnameChanged);
    on<RegisterSecondSurnameChanged>(_onSecondSurnameChanged);
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterCareerChanged>(_onCareerChanged);
    on<RegisterSemesterChanged>(_onSemesterChanged);
    on<RegisterGroupChanged>(_onGroupChanged);
    on<RegisterTermsAcceptanceChanged>(_onTermsAcceptanceChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterPasswordConfirmationChanged>(_onPasswordConfirmationChanged);
    on<RegisterLegalDocumentsRequested>(_onLegalDocumentsRequested);
    on<RegisterSubmitted>(_onSubmitted);

    add(const RegisterLegalDocumentsRequested());
  }

  final UserRepository _userRepository;
  final AcademicCatalogRepository _academicCatalogRepository;
  final LegalDocumentRepository _legalDocumentRepository;

  void _onGivenNamesChanged(
    RegisterGivenNamesChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        givenNames: event.givenNames,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onFirstSurnameChanged(
    RegisterFirstSurnameChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        firstSurname: event.firstSurname,
        status: FormzSubmissionStatus.initial,
        clearErrorMessage: true,
      ),
    );
  }

  void _onSecondSurnameChanged(
    RegisterSecondSurnameChanged event,
    Emitter<RegisterState> emit,
  ) {
    _emitValidated(
      emit,
      state.copyWith(
        secondSurname: event.secondSurname,
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

  Future<void> _onLegalDocumentsRequested(
    RegisterLegalDocumentsRequested event,
    Emitter<RegisterState> emit,
  ) async {
    emit(
      state.copyWith(
        legalDocumentsStatus: LegalDocumentsStatus.loading,
        legalDocuments: const [],
        termsAccepted: false,
        clearErrorMessage: true,
      ),
    );

    try {
      final documents =
          await _legalDocumentRepository.fetchRegistrationDocuments();

      final next = state.copyWith(
        legalDocuments: documents,
        legalDocumentsStatus: LegalDocumentsStatus.success,
      );

      _emitValidated(emit, next);
    } catch (error, stackTrace) {
      final next = state.copyWith(
        legalDocuments: const [],
        legalDocumentsStatus: LegalDocumentsStatus.failure,
        termsAccepted: false,
        errorMessage:
            'No fue posible cargar los documentos legales requeridos.',
      );

      _emitValidated(emit, next);
      addError(error, stackTrace);
    }
  }

  Future<void> _loadGroupsIfReady(Emitter<RegisterState> emit) async {
    final current = state;

    if (!current.isStudent ||
        current.careerId == null ||
        current.semester == null) {
      return;
    }

    final loadingState = current.copyWith(
      groupsStatus: AcademicGroupsStatus.loading,
      availableGroups: const [],
      clearGroupId: true,
    );

    emit(loadingState.copyWith(valid: _validateState(loadingState)));

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

    final termsDocument = submittedState.termsDocument;
    final privacyDocument = submittedState.privacyDocument;

    if (termsDocument == null || privacyDocument == null) {
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage:
              'No están disponibles los documentos legales requeridos.',
        ),
      );
      return;
    }

    final institutionalEmail = email.institutionalEmail;
    final isStudent = institutionalEmail.type.isStudent;
    final hasGroupCatalog = submittedState.availableGroups.isNotEmpty;
    final legalAcceptedAt = DateTime.now().toUtc().toIso8601String();

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    try {
      await _userRepository.signUpWithPassword(
        email: email.normalizedValue,
        password: password.value,
        data: {
          'display_name': _normalizeFullName(submittedState),
          'institutionalEmailType': institutionalEmail.type.name,
          'termsAccepted': true,
          'privacyAccepted': true,
          'termsDocumentVersion': termsDocument.version,
          'privacyDocumentVersion': privacyDocument.version,
          'legalAcceptedAt': legalAcceptedAt,
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

  static bool _isValidNamePart(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.length < 2) {
      return false;
    }

    return RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' -]+$").hasMatch(normalized);
  }

  static String _normalizeNamePart(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    return normalized
        .split(' ')
        .map((part) {
          if (part.isEmpty) {
            return part;
          }

          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static String _normalizeFullName(RegisterState state) {
    return [
      _normalizeNamePart(state.givenNames),
      _normalizeNamePart(state.firstSurname),
      _normalizeNamePart(state.secondSurname),
    ].join(' ');
  }

  static bool _validateState(RegisterState state) {
    final namesValid = _isValidNamePart(state.givenNames);
    final firstSurnameValid = _isValidNamePart(state.firstSurname);
    final secondSurnameValid = _isValidNamePart(state.secondSurname);

    final credentialsValid = Formz.validate([
      state.email,
      state.password,
      state.passwordConfirmation,
    ]);

    final commonValid =
        namesValid &&
        firstSurnameValid &&
        secondSurnameValid &&
        credentialsValid &&
        state.termsAccepted &&
        state.legalDocumentsReady &&
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
        message.contains('user already exists') ||
        message.contains('email already exists') ||
        message.contains('already been registered')) {
      return 'Ya existe una cuenta asociada a este correo institucional. '
          'Inicia sesión o recupera tu contraseña.';
    }

    if (message.contains('terms') ||
        message.contains('privacy') ||
        message.contains('legal document')) {
      return 'Los documentos legales cambiaron. '
          'Revisa y acepta nuevamente las condiciones.';
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
