part of 'app_bloc.dart';

enum AppStatus {
  onboardingRequired(),
  authenticated(),
  unauthenticated();

  bool get isLoggedIn =>
      this == AppStatus.authenticated || this == AppStatus.onboardingRequired;
}

class AppState extends Equatable {
  const AppState({
    required this.status,
    this.isAmoled = false,
    this.user = User.anonymous,
    this.institutionalProfile,
    this.pendingAnnouncementId,
    this.pendingAcademicTaskId,
    this.pendingClassSessionId,
    this.pendingClassSubjectId,
  });

  const AppState.authenticated(
    User user, {
    bool isAmoled = false,
    AppUserProfile? institutionalProfile,
  }) : this(
         status: AppStatus.authenticated,
         user: user,
         isAmoled: isAmoled,
         institutionalProfile: institutionalProfile,
       );

  const AppState.onboardingRequired(
    User user, {
    bool isAmoled = false,
    AppUserProfile? institutionalProfile,
  }) : this(
         status: AppStatus.onboardingRequired,
         user: user,
         isAmoled: isAmoled,
         institutionalProfile: institutionalProfile,
       );

  const AppState.unauthenticated({bool isAmoled = false})
    : this(status: AppStatus.unauthenticated, isAmoled: isAmoled);

  final AppStatus status;
  final User user;
  final bool isAmoled;

  /// Institutional Firestore profile used for roles and segmentation.
  final AppUserProfile? institutionalProfile;

  /// Announcement waiting to be opened from a notification interaction.
  ///
  /// This value is intentionally not persisted by HydratedBloc.
  final String? pendingAnnouncementId;

  /// Academic task waiting to be opened from a local reminder.
  ///
  /// This value is intentionally not persisted by HydratedBloc.
  final String? pendingAcademicTaskId;

  /// Class session waiting to be opened from a local reminder.
  ///
  /// These values are intentionally not persisted by HydratedBloc.
  final String? pendingClassSessionId;
  final String? pendingClassSubjectId;

  bool get hasInstitutionalProfile => institutionalProfile != null;

  AppState copyWith({
    bool? isAmoled,
    AppStatus? status,
    User? user,
    AppUserProfile? institutionalProfile,
    bool clearInstitutionalProfile = false,
    String? pendingAnnouncementId,
    bool clearPendingAnnouncementId = false,
    String? pendingAcademicTaskId,
    bool clearPendingAcademicTaskId = false,
    String? pendingClassSessionId,
    String? pendingClassSubjectId,
    bool clearPendingClassSession = false,
  }) {
    return AppState(
      isAmoled: isAmoled ?? this.isAmoled,
      status: status ?? this.status,
      user: user ?? this.user,
      institutionalProfile:
          clearInstitutionalProfile
              ? null
              : institutionalProfile ?? this.institutionalProfile,
      pendingAnnouncementId:
          clearPendingAnnouncementId
              ? null
              : pendingAnnouncementId ?? this.pendingAnnouncementId,
      pendingAcademicTaskId:
          clearPendingAcademicTaskId
              ? null
              : pendingAcademicTaskId ?? this.pendingAcademicTaskId,
      pendingClassSessionId:
          clearPendingClassSession
              ? null
              : pendingClassSessionId ?? this.pendingClassSessionId,
      pendingClassSubjectId:
          clearPendingClassSession
              ? null
              : pendingClassSubjectId ?? this.pendingClassSubjectId,
    );
  }

  @override
  List<Object?> get props => [
    isAmoled,
    status,
    user,
    institutionalProfile,
    pendingAnnouncementId,
    pendingAcademicTaskId,
    pendingClassSessionId,
    pendingClassSubjectId,
  ];
}
