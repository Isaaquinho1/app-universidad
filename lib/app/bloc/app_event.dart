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

class ThemeChanged extends AppEvent {
  const ThemeChanged(this.isAmoled);

  final bool isAmoled;

  @override
  List<Object?> get props => [isAmoled];
}

class AppUserChanged extends AppEvent {
  const AppUserChanged(this.user);

  final User user;

  @override
  List<Object> get props => [user];
}

/// Emitted whenever the institutional Firestore profile changes.
class AppInstitutionalProfileChanged extends AppEvent {
  const AppInstitutionalProfileChanged(this.profile);

  final AppUserProfile? profile;

  @override
  List<Object?> get props => [profile];
}

class AppLogoutRequested extends AppEvent {
  const AppLogoutRequested();
}
