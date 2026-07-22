import 'package:conecta_itt/announcements/models/announcement_results.dart';

class AnnouncementReminderPreview {
  const AnnouncementReminderPreview({
    required this.announcementId,
    required this.title,
    required this.contentVersion,
    required this.criterion,
    required this.eligibleCount,
    required this.recipients,
  });

  final String announcementId;
  final String title;
  final int contentVersion;
  final String criterion;
  final int eligibleCount;
  final List<AnnouncementResultRecipient> recipients;

  factory AnnouncementReminderPreview.fromJson(Map<String, dynamic> json) {
    final recipientValues = json['recipients'];

    return AnnouncementReminderPreview(
      announcementId: json['announcement_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      contentVersion: _readInt(json['content_version']) ?? 1,
      criterion: json['criterion'] as String? ?? '',
      eligibleCount: _readInt(json['eligible_count']) ?? 0,
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

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
