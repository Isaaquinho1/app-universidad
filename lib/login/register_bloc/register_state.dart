part of 'register_bloc.dart';

enum AcademicGroupsStatus { initial, loading, success, failure }

enum LegalDocumentsStatus { initial, loading, success, failure }

class RegisterState extends Equatable {
  const RegisterState({
    this.fullName = '',
    this.email = const RegisterEmail.pure(),
    this.password = const RegisterPassword.pure(),
    this.passwordConfirmation = const RegisterPasswordConfirmation.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.valid = false,
    this.emailType = InstitutionalEmailType.invalid,
    this.controlNumber,
    this.careerId,
    this.semester,
    this.groupId,
    this.availableGroups = const [],
    this.groupsStatus = AcademicGroupsStatus.initial,
    this.termsAccepted = false,
    this.legalDocuments = const [],
    this.legalDocumentsStatus = LegalDocumentsStatus.initial,
    this.errorMessage,
  });

  final String fullName;
  final RegisterEmail email;
  final RegisterPassword password;
  final RegisterPasswordConfirmation passwordConfirmation;
  final FormzSubmissionStatus status;
  final bool valid;
  final InstitutionalEmailType emailType;
  final String? controlNumber;

  final String? careerId;
  final int? semester;
  final String? groupId;
  final List<AcademicGroup> availableGroups;
  final AcademicGroupsStatus groupsStatus;

  final bool termsAccepted;
  final List<LegalDocument> legalDocuments;
  final LegalDocumentsStatus legalDocumentsStatus;

  final String? errorMessage;

  bool get isStudent => emailType.isStudent;

  bool get isStaff => emailType.isStaff;

  bool get hasConfiguredGroups => availableGroups.isNotEmpty;

  bool get academicSelectionReady => careerId != null && semester != null;

  LegalDocument? get termsDocument {
    for (final document in legalDocuments) {
      if (document.isTerms) {
        return document;
      }
    }

    return null;
  }

  LegalDocument? get privacyDocument {
    for (final document in legalDocuments) {
      if (document.isPrivacy) {
        return document;
      }
    }

    return null;
  }

  bool get legalDocumentsReady =>
      legalDocumentsStatus == LegalDocumentsStatus.success &&
      termsDocument != null &&
      privacyDocument != null;

  RegisterState copyWith({
    String? fullName,
    RegisterEmail? email,
    RegisterPassword? password,
    RegisterPasswordConfirmation? passwordConfirmation,
    FormzSubmissionStatus? status,
    bool? valid,
    InstitutionalEmailType? emailType,
    String? controlNumber,
    bool clearControlNumber = false,
    String? careerId,
    bool clearCareerId = false,
    int? semester,
    bool clearSemester = false,
    String? groupId,
    bool clearGroupId = false,
    List<AcademicGroup>? availableGroups,
    AcademicGroupsStatus? groupsStatus,
    bool? termsAccepted,
    List<LegalDocument>? legalDocuments,
    LegalDocumentsStatus? legalDocumentsStatus,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RegisterState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      passwordConfirmation: passwordConfirmation ?? this.passwordConfirmation,
      status: status ?? this.status,
      valid: valid ?? this.valid,
      emailType: emailType ?? this.emailType,
      controlNumber:
          clearControlNumber ? null : controlNumber ?? this.controlNumber,
      careerId: clearCareerId ? null : careerId ?? this.careerId,
      semester: clearSemester ? null : semester ?? this.semester,
      groupId: clearGroupId ? null : groupId ?? this.groupId,
      availableGroups: availableGroups ?? this.availableGroups,
      groupsStatus: groupsStatus ?? this.groupsStatus,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      legalDocuments: legalDocuments ?? this.legalDocuments,
      legalDocumentsStatus: legalDocumentsStatus ?? this.legalDocumentsStatus,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    fullName,
    email,
    password,
    passwordConfirmation,
    status,
    valid,
    emailType,
    controlNumber,
    careerId,
    semester,
    groupId,
    availableGroups,
    groupsStatus,
    termsAccepted,
    legalDocuments,
    legalDocumentsStatus,
    errorMessage,
  ];
}
