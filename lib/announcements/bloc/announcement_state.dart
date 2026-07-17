part of 'announcement_bloc.dart';

enum AnnouncementsStatus { initial, loading, populated, failure }

class AnnouncementState extends Equatable {
  const AnnouncementState({
    this.status = AnnouncementsStatus.initial,
    this.announcements = const [],
    this.receiptsByAnnouncementId = const {},
  });

  final AnnouncementsStatus status;
  final List<Announcement> announcements;
  final Map<String, AnnouncementReceipt> receiptsByAnnouncementId;

  AnnouncementState copyWith({
    AnnouncementsStatus? status,
    List<Announcement>? announcements,
    Map<String, AnnouncementReceipt>? receiptsByAnnouncementId,
  }) {
    return AnnouncementState(
      status: status ?? this.status,
      announcements: announcements ?? this.announcements,
      receiptsByAnnouncementId:
          receiptsByAnnouncementId ?? this.receiptsByAnnouncementId,
    );
  }

  @override
  List<Object> get props => [status, announcements, receiptsByAnnouncementId];
}
