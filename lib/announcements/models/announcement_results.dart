class AnnouncementResults {
  const AnnouncementResults({
    required this.announcementId,
    required this.title,
    required this.status,
    required this.contentVersion,
    required this.summary,
    required this.recipients,
    this.publishedAt,
    this.updatedAt,
  });

  final String announcementId;
  final String title;
  final String status;
  final int contentVersion;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final AnnouncementResultsSummary summary;
  final List<AnnouncementResultRecipient> recipients;

  factory AnnouncementResults.fromJson(Map<String, dynamic> json) {
    final summaryJson = _readMap(json['summary']);
    final recipientValues = json['recipients'];

    return AnnouncementResults(
      announcementId: json['announcement_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      contentVersion: _readInt(json['content_version']) ?? 1,
      publishedAt: _readDateTime(json['published_at']),
      updatedAt: _readDateTime(json['updated_at']),
      summary: AnnouncementResultsSummary.fromJson(summaryJson),
      recipients:
          recipientValues is Iterable
              ? recipientValues
                  .whereType<Map>()
                  .map(
                    (value) => AnnouncementResultRecipient.fromJson(
                      value.map((key, item) => MapEntry(key.toString(), item)),
                    ),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const {};
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

class AnnouncementResultsSummary {
  const AnnouncementResultsSummary({
    required this.audienceTotal,
    required this.pending,
    required this.edited,
    required this.delivered,
    required this.seen,
    required this.read,
    required this.confirmed,
  });

  final int audienceTotal;
  final int pending;
  final int edited;
  final int delivered;
  final int seen;
  final int read;
  final int confirmed;

  int get requiresAttention => pending + edited + delivered;

  factory AnnouncementResultsSummary.fromJson(Map<String, dynamic> json) {
    return AnnouncementResultsSummary(
      audienceTotal: _readInt(json['audience_total']),
      pending: _readInt(json['pending']),
      edited: _readInt(json['edited']),
      delivered: _readInt(json['delivered']),
      seen: _readInt(json['seen']),
      read: _readInt(json['read']),
      confirmed: _readInt(json['confirmed']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AnnouncementResultRecipient {
  const AnnouncementResultRecipient({
    required this.userUid,
    required this.status,
    this.email,
    this.displayName,
    this.role,
    this.careerId,
    this.semester,
    this.groupId,
    this.controlNumber,
    this.receiptVersion,
    this.deliveredAt,
    this.seenAt,
    this.readAt,
    this.confirmedAt,
    this.updatedAt,
  });

  final String userUid;
  final String status;
  final String? email;
  final String? displayName;
  final String? role;
  final String? careerId;
  final int? semester;
  final String? groupId;
  final String? controlNumber;
  final int? receiptVersion;
  final DateTime? deliveredAt;
  final DateTime? seenAt;
  final DateTime? readAt;
  final DateTime? confirmedAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'pending';

  bool get isEdited => status == 'edited';

  factory AnnouncementResultRecipient.fromJson(Map<String, dynamic> json) {
    return AnnouncementResultRecipient(
      userUid: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      role: json['role'] as String?,
      careerId: json['career_id'] as String?,
      semester: _readInt(json['semester']),
      groupId: json['group_id'] as String?,
      controlNumber: json['control_number'] as String?,
      receiptVersion: _readInt(json['receipt_version']),
      deliveredAt: _readDateTime(json['delivered_at']),
      seenAt: _readDateTime(json['seen_at']),
      readAt: _readDateTime(json['read_at']),
      confirmedAt: _readDateTime(json['confirmed_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  DateTime? get lastActivity =>
      confirmedAt ?? readAt ?? seenAt ?? deliveredAt ?? updatedAt;

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
