part of 'announcement_bloc.dart';

enum AnnouncementsStatus { initial, loading, populated, failure }

class AnnouncementState extends Equatable {
  const AnnouncementState({
    this.status = AnnouncementsStatus.initial,
    this.announcements = const [],
  });

  final AnnouncementsStatus status;
  final List<Announcement> announcements;

  AnnouncementState copyWith({
    AnnouncementsStatus? status,
    List<Announcement>? announcements,
  }) {
    return AnnouncementState(
      status: status ?? this.status,
      announcements: announcements ?? this.announcements,
    );
  }

  @override
  List<Object> get props => [status, announcements];
}
