import 'package:rtu_mirea_app/institutional_profile/models/models.dart';

class AnnouncementRecipient {
  const AnnouncementRecipient({
    required this.uid,
    required this.role,
    this.email,
    this.displayName,
    this.careerId,
    this.semester,
    this.groupId,
    this.controlNumber,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final AppUserRole role;
  final String? careerId;
  final int? semester;
  final String? groupId;
  final String? controlNumber;

  factory AnnouncementRecipient.fromSupabase(Map<String, dynamic> row) {
    return AnnouncementRecipient(
      uid: row['id'] as String? ?? '',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      role: AppUserRole.fromValue(row['role'] as String?),
      careerId: row['career_id'] as String?,
      semester: _readInt(row['semester']),
      groupId: row['group_id'] as String?,
      controlNumber: row['control_number'] as String?,
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
