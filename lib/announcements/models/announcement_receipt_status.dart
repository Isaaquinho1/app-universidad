/// Progress status of an announcement receipt for a specific user.
enum AnnouncementReceiptStatus {
  delivered,
  seen,
  read,
  confirmed;

  String get value {
    switch (this) {
      case AnnouncementReceiptStatus.delivered:
        return 'delivered';
      case AnnouncementReceiptStatus.seen:
        return 'seen';
      case AnnouncementReceiptStatus.read:
        return 'read';
      case AnnouncementReceiptStatus.confirmed:
        return 'confirmed';
    }
  }

  int get level {
    switch (this) {
      case AnnouncementReceiptStatus.delivered:
        return 0;
      case AnnouncementReceiptStatus.seen:
        return 1;
      case AnnouncementReceiptStatus.read:
        return 2;
      case AnnouncementReceiptStatus.confirmed:
        return 3;
    }
  }

  bool isAtLeast(AnnouncementReceiptStatus other) {
    return level >= other.level;
  }

  static AnnouncementReceiptStatus fromValue(String? value) {
    switch (value) {
      case 'seen':
        return AnnouncementReceiptStatus.seen;
      case 'read':
        return AnnouncementReceiptStatus.read;
      case 'confirmed':
        return AnnouncementReceiptStatus.confirmed;
      case 'delivered':
      default:
        return AnnouncementReceiptStatus.delivered;
    }
  }
}
