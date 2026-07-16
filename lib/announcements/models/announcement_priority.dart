/// Importance level of an institutional announcement.
enum AnnouncementPriority {
  low,
  normal,
  high,
  urgent;

  String get value {
    switch (this) {
      case AnnouncementPriority.low:
        return 'low';
      case AnnouncementPriority.normal:
        return 'normal';
      case AnnouncementPriority.high:
        return 'high';
      case AnnouncementPriority.urgent:
        return 'urgent';
    }
  }

  static AnnouncementPriority fromValue(String? value) {
    switch (value) {
      case 'low':
        return AnnouncementPriority.low;
      case 'high':
        return AnnouncementPriority.high;
      case 'urgent':
        return AnnouncementPriority.urgent;
      case 'normal':
      default:
        return AnnouncementPriority.normal;
    }
  }
}
