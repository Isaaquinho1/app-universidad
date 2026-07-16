/// Lifecycle status of an institutional announcement.
enum AnnouncementStatus {
  draft,
  scheduled,
  published,
  archived;

  String get value {
    switch (this) {
      case AnnouncementStatus.draft:
        return 'draft';
      case AnnouncementStatus.scheduled:
        return 'scheduled';
      case AnnouncementStatus.published:
        return 'published';
      case AnnouncementStatus.archived:
        return 'archived';
    }
  }

  bool get isVisibleToStudents => this == AnnouncementStatus.published;

  static AnnouncementStatus fromValue(String? value) {
    switch (value) {
      case 'scheduled':
        return AnnouncementStatus.scheduled;
      case 'published':
        return AnnouncementStatus.published;
      case 'archived':
        return AnnouncementStatus.archived;
      case 'draft':
      default:
        return AnnouncementStatus.draft;
    }
  }
}
