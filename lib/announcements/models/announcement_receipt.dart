import 'announcement_receipt_status.dart';

/// User-specific delivery and reading state for an announcement.
class AnnouncementReceipt {
  const AnnouncementReceipt({
    required this.userUid,
    required this.status,
    this.receiptVersion = 1,
    this.deliveredAt,
    this.seenAt,
    this.readAt,
    this.confirmedAt,
    this.updatedAt,
  });

  final String userUid;
  final AnnouncementReceiptStatus status;
  final int receiptVersion;
  final DateTime? deliveredAt;
  final DateTime? seenAt;
  final DateTime? readAt;
  final DateTime? confirmedAt;
  final DateTime? updatedAt;

  bool get isDelivered => status.isAtLeast(AnnouncementReceiptStatus.delivered);

  bool get isSeen => status.isAtLeast(AnnouncementReceiptStatus.seen);

  bool get isRead => status.isAtLeast(AnnouncementReceiptStatus.read);

  bool get isConfirmed => status.isAtLeast(AnnouncementReceiptStatus.confirmed);

  factory AnnouncementReceipt.fromSupabase(Map<String, dynamic> row) {
    return AnnouncementReceipt(
      userUid: row['user_id'] as String? ?? '',
      status: AnnouncementReceiptStatus.fromValue(row['status'] as String?),
      receiptVersion: _readInt(row['receipt_version']) ?? 1,
      deliveredAt: _readDateTime(row['delivered_at']),
      seenAt: _readDateTime(row['seen_at']),
      readAt: _readDateTime(row['read_at']),
      confirmedAt: _readDateTime(row['confirmed_at']),
      updatedAt: _readDateTime(row['updated_at']),
    );
  }

  factory AnnouncementReceipt.fromJson(Map<String, dynamic> json) {
    return AnnouncementReceipt(
      userUid: json['userUid'] as String? ?? json['user_id'] as String? ?? '',
      status: AnnouncementReceiptStatus.fromValue(json['status'] as String?),
      receiptVersion:
          _readInt(json['receiptVersion'] ?? json['receipt_version']) ?? 1,
      deliveredAt: _readDateTime(json['deliveredAt'] ?? json['delivered_at']),
      seenAt: _readDateTime(json['seenAt'] ?? json['seen_at']),
      readAt: _readDateTime(json['readAt'] ?? json['read_at']),
      confirmedAt: _readDateTime(json['confirmedAt'] ?? json['confirmed_at']),
      updatedAt: _readDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userUid': userUid,
      'status': status.value,
      'receiptVersion': receiptVersion,
      'deliveredAt': deliveredAt,
      'seenAt': seenAt,
      'readAt': readAt,
      'confirmedAt': confirmedAt,
      'updatedAt': updatedAt,
    };
  }

  AnnouncementReceipt copyWith({
    String? userUid,
    AnnouncementReceiptStatus? status,
    int? receiptVersion,
    DateTime? deliveredAt,
    DateTime? seenAt,
    DateTime? readAt,
    DateTime? confirmedAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementReceipt(
      userUid: userUid ?? this.userUid,
      status: status ?? this.status,
      receiptVersion: receiptVersion ?? this.receiptVersion,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      seenAt: seenAt ?? this.seenAt,
      readAt: readAt ?? this.readAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
