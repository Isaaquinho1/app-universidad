import 'announcement_priority.dart';
import 'announcement_status.dart';
import 'announcement_target.dart';

/// Institutional announcement stored in Supabase.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.target,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.contentVersion = 1,
    this.summary,
    this.authorName,
    this.publishedAt,
    this.expiresAt,
    this.attachmentUrls = const [],
  });

  final String id;
  final String title;
  final String body;
  final String? summary;
  final String authorUid;
  final String? authorName;
  final AnnouncementTarget target;
  final AnnouncementStatus status;
  final AnnouncementPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int contentVersion;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final List<String> attachmentUrls;

  bool get isPublished => status == AnnouncementStatus.published;

  bool get isArchived => status == AnnouncementStatus.archived;

  bool get isScheduled => status == AnnouncementStatus.scheduled;

  bool get isExpired {
    final expiration = expiresAt;

    if (expiration == null) {
      return false;
    }

    return expiration.isBefore(DateTime.now());
  }

  bool get isVisibleToStudents => status.isVisibleToStudents && !isExpired;

  factory Announcement.fromSupabase(Map<String, dynamic> row) {
    return Announcement(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      summary: row['summary'] as String?,
      authorUid: row['author_id'] as String? ?? '',
      authorName: row['author_name'] as String?,
      target: AnnouncementTarget.fromJson(_readMap(row['target'])),
      status: AnnouncementStatus.fromValue(row['status'] as String?),
      priority: AnnouncementPriority.fromValue(row['priority'] as String?),
      createdAt:
          _readDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      contentVersion: _readInt(row['content_version']) ?? 1,
      publishedAt: _readDateTime(row['published_at']),
      expiresAt: _readDateTime(row['expires_at']),
      attachmentUrls: _readStringList(row['attachment_urls']),
    );
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      summary: json['summary'] as String?,
      authorUid:
          json['authorUid'] as String? ?? json['author_id'] as String? ?? '',
      authorName:
          json['authorName'] as String? ?? json['author_name'] as String?,
      target: AnnouncementTarget.fromJson(_readMap(json['target'])),
      status: AnnouncementStatus.fromValue(json['status'] as String?),
      priority: AnnouncementPriority.fromValue(json['priority'] as String?),
      createdAt:
          _readDateTime(json['createdAt'] ?? json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(json['updatedAt'] ?? json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      contentVersion:
          _readInt(json['contentVersion'] ?? json['content_version']) ?? 1,
      publishedAt: _readDateTime(json['publishedAt'] ?? json['published_at']),
      expiresAt: _readDateTime(json['expiresAt'] ?? json['expires_at']),
      attachmentUrls: _readStringList(
        json['attachmentUrls'] ?? json['attachment_urls'],
      ),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'title': title,
      'body': body,
      'summary': summary,
      'author_id': authorUid,
      'author_name': authorName,
      'status': status.value,
      'priority': priority.value,
      'all_users': target.allUsers,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'attachment_urls': attachmentUrls,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'summary': summary,
      'authorUid': authorUid,
      'authorName': authorName,
      'target': target.toJson(),
      'status': status.value,
      'priority': priority.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'contentVersion': contentVersion,
      'publishedAt': publishedAt,
      'expiresAt': expiresAt,
      'attachmentUrls': attachmentUrls,
    };
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    String? summary,
    String? authorUid,
    String? authorName,
    AnnouncementTarget? target,
    AnnouncementStatus? status,
    AnnouncementPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? contentVersion,
    DateTime? publishedAt,
    DateTime? expiresAt,
    List<String>? attachmentUrls,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      summary: summary ?? this.summary,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      target: target ?? this.target,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contentVersion: contentVersion ?? this.contentVersion,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    return const {};
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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
