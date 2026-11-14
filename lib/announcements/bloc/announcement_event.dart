part of 'announcement_bloc.dart';

sealed class AnnouncementEvent extends Equatable {
  const AnnouncementEvent();

  @override
  List<Object?> get props => [];
}

final class AnnouncementsStarted extends AnnouncementEvent {
  const AnnouncementsStarted({this.refreshCompletion});

  final Completer<void>? refreshCompletion;
}

final class AnnouncementsChanged extends AnnouncementEvent {
  const AnnouncementsChanged(this.announcements, {this.refreshCompletion});

  final Completer<void>? refreshCompletion;

  final List<Announcement> announcements;

  @override
  List<Object?> get props => [announcements];
}

final class AnnouncementsFailed extends AnnouncementEvent {
  const AnnouncementsFailed(
    this.error,
    this.stackTrace, {
    this.refreshCompletion,
  });

  final Completer<void>? refreshCompletion;

  final Object error;
  final StackTrace stackTrace;

  @override
  List<Object?> get props => [error, stackTrace];
}
