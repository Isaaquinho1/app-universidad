part of 'announcement_bloc.dart';

sealed class AnnouncementEvent extends Equatable {
  const AnnouncementEvent();

  @override
  List<Object?> get props => [];
}

final class AnnouncementsStarted extends AnnouncementEvent {
  const AnnouncementsStarted();
}

final class AnnouncementsChanged extends AnnouncementEvent {
  const AnnouncementsChanged(this.announcements);

  final List<Announcement> announcements;

  @override
  List<Object?> get props => [announcements];
}

final class AnnouncementsFailed extends AnnouncementEvent {
  const AnnouncementsFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  List<Object?> get props => [error, stackTrace];
}
