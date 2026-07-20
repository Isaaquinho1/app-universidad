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

  bool get hasInstitutionalProfile => institutionalProfile != null;

  AppState copyWith({
    bool? isAmoled,
    AppStatus? status,
    User? user,
    AppUserProfile? institutionalProfile,
    bool clearInstitutionalProfile = false,
    String? pendingAnnouncementId,
    bool clearPendingAnnouncementId = false,
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
    );
  }

  @override
  List<Object?> get props => [
    isAmoled,
    status,
    user,
    institutionalProfile,
    pendingAnnouncementId,
  ];
}
