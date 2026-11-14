part of 'app_bloc.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class AppOpened extends AppEvent {
  const AppOpened();
}

class RecieveInteractedMessage extends AppEvent {
  const RecieveInteractedMessage(this.message);

  final RemoteMessage message;

  @override
  List<Object?> get props => [message];
}

class AnnouncementNotificationOpened extends AppEvent {
  const AnnouncementNotificationOpened(this.announcementId);

  final String announcementId;

  @override
  List<Object?> get props => [announcementId];
}

class AnnouncementNavigationConsumed extends AppEvent {
  const AnnouncementNavigationConsumed();
}

class ProfilePhotoReviewNotificationOpened extends AppEvent {
  const ProfilePhotoReviewNotificationOpened({
    required this.decision,
    required this.userId,
    required this.authRevision,
  });

  final String decision;
  final String userId;
  final int authRevision;

  @override
  List<Object?> get props => [decision, userId, authRevision];
}

class ProfilePhotoReviewNavigationConsumed extends AppEvent {
  const ProfilePhotoReviewNavigationConsumed({
    required this.userId,
    required this.authRevision,
  });

  final String userId;
  final int authRevision;

  @override
  List<Object?> get props => [userId, authRevision];
}

class AcademicTaskNotificationOpened extends AppEvent {
  const AcademicTaskNotificationOpened(
    this.taskId, {
    required this.userId,
    required this.authRevision,
  });

  final String taskId;
  final String userId;
  final int authRevision;

  @override
  List<Object?> get props => [taskId, userId, authRevision];
}

class AcademicTaskNavigationConsumed extends AppEvent {
  const AcademicTaskNavigationConsumed({
    required this.taskId,
    required this.authRevision,
  });

  final String taskId;
  final int authRevision;

  @override
  List<Object?> get props => [taskId, authRevision];
}

class ClassSessionNotificationOpened extends AppEvent {
  const ClassSessionNotificationOpened({
    required this.sessionId,
    required this.subjectId,
    required this.userId,
    required this.authRevision,
  });

  final String sessionId;
  final String subjectId;
  final String userId;
  final int authRevision;

  @override
  List<Object?> get props => [sessionId, subjectId, userId, authRevision];
}

class ClassSessionNavigationConsumed extends AppEvent {
  const ClassSessionNavigationConsumed({
    required this.sessionId,
    required this.subjectId,
    required this.authRevision,
  });

  final String sessionId;
  final String subjectId;
  final int authRevision;

  @override
  List<Object?> get props => [sessionId, subjectId, authRevision];
}

class ThemeChanged extends AppEvent {
  const ThemeChanged(this.isAmoled);

  final bool isAmoled;

  @override
  List<Object?> get props => [isAmoled];
}

class AppProfileRetryRequested extends AppEvent {
  const AppProfileRetryRequested();
}

class AppUserChanged extends AppEvent {
  const AppUserChanged(this.user, {required this.revision});

  final User user;
  final int revision;

  @override
  List<Object> get props => [user, revision];
}

/// Emitted whenever the institutional Firestore profile changes.
class AppInstitutionalProfileChanged extends AppEvent {
  const AppInstitutionalProfileChanged(
    this.profile, {
    required this.userId,
    required this.revision,
  });

  final AppUserProfile? profile;
  final String userId;
  final int revision;

  @override
  List<Object?> get props => [profile, userId, revision];
}

class AppLogoutRequested extends AppEvent {
  const AppLogoutRequested();
}
