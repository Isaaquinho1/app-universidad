class AnnouncementNotificationMetrics {
  const AnnouncementNotificationMetrics({
    required this.announcementId,
    required this.contentVersion,
    required this.requested,
    required this.status,
    required this.audienceCount,
    required this.tokenCount,
    required this.sentCount,
    required this.failedCount,
    required this.noTokenCount,
    required this.invalidTokenCount,
    this.dispatchId,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String? dispatchId;
  final String announcementId;
  final int contentVersion;
  final bool requested;
  final String status;

  final int audienceCount;
  final int tokenCount;
  final int sentCount;
  final int failedCount;
  final int noTokenCount;
  final int invalidTokenCount;

  final String? errorMessage;

  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get wasRequested => requested;

  bool get isProcessing => status == 'processing';

  bool get isCompleted => status == 'completed';

  bool get isFailed => status == 'failed';

  bool get hasFailures =>
      failedCount > 0 || invalidTokenCount > 0 || errorMessage != null;

  int get successfulAudienceCount => sentCount;

  int get unresolvedAudienceCount {
    final unresolved = audienceCount - sentCount;

    return unresolved < 0 ? 0 : unresolved;
  }

  double get successRate {
    if (tokenCount == 0) {
      return 0;
    }

    return sentCount / tokenCount;
  }

  factory AnnouncementNotificationMetrics.fromJson(Map<String, dynamic> json) {
    return AnnouncementNotificationMetrics(
      dispatchId: _readString(json['dispatch_id']),
      announcementId: _readString(json['announcement_id']) ?? '',
      contentVersion: _readInt(json['content_version']),
      requested: _readBool(json['requested']),
      status: _readString(json['status']) ?? 'not_requested',
      audienceCount: _readInt(json['audience_count']),
      tokenCount: _readInt(json['token_count']),
      sentCount: _readInt(json['sent_count']),
      failedCount: _readInt(json['failed_count']),
      noTokenCount: _readInt(json['no_token_count']),
      invalidTokenCount: _readInt(json['invalid_token_count']),
      errorMessage: _readString(json['error_message']),
      startedAt: _readDateTime(json['started_at']),
      completedAt: _readDateTime(json['completed_at']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  static String? _readString(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
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

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();

    return normalized == 'true' || normalized == '1';
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
