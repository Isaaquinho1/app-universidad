import 'app_user_role.dart';

/// Institutional and academic profile associated with an authenticated user.
class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.role,
    required this.profileCompleted,
    required this.active,
    this.email,
    this.displayName,
    this.careerId,
    this.semester,
    this.groupId,
    this.controlNumber,
    this.fcmTokens = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final AppUserRole role;
  final String? careerId;
  final int? semester;
  final String? groupId;
  final String? controlNumber;
  final Map<String, String> fcmTokens;
  final bool profileCompleted;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isStudent => role == AppUserRole.student;

  bool get isTeacher => role == AppUserRole.teacher;

  bool get isAdmin => role == AppUserRole.admin;

  bool get isSuperAdmin => role == AppUserRole.superAdmin;

  bool get canManageAnnouncements => role.canManageAnnouncements;

  bool get canManageAdmins => role.canManageAdmins;

  /// Creates a profile from a Supabase/PostgREST row.
  factory AppUserProfile.fromSupabase(Map<String, dynamic> row) {
    return AppUserProfile(
      uid: row['id'] as String? ?? '',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      role: AppUserRole.fromValue(row['role'] as String?),
      careerId: row['career_id'] as String?,
      semester: _readInt(row['semester']),
      groupId: row['group_id'] as String?,
      controlNumber: row['control_number'] as String?,
      profileCompleted: row['profile_completed'] as bool? ?? false,
      active: row['active'] as bool? ?? true,
      createdAt: _readDateTime(row['created_at']),
      updatedAt: _readDateTime(row['updated_at']),
    );
  }

  /// Creates a profile from either legacy camelCase data or Supabase data.
  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      email: json['email'] as String?,
      displayName:
          json['displayName'] as String? ?? json['display_name'] as String?,
      role: AppUserRole.fromValue(json['role'] as String?),
      careerId: json['careerId'] as String? ?? json['career_id'] as String?,
      semester: _readInt(json['semester']),
      groupId: json['groupId'] as String? ?? json['group_id'] as String?,
      controlNumber:
          json['controlNumber'] as String? ?? json['control_number'] as String?,
      fcmTokens: _readStringMap(json['fcmTokens']),
      profileCompleted:
          json['profileCompleted'] as bool? ??
          json['profile_completed'] as bool? ??
          false,
      active: json['active'] as bool? ?? true,
      createdAt: _readDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _readDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'careerId': careerId,
      'semester': semester,
      'groupId': groupId,
      'controlNumber': controlNumber,
      'fcmTokens': fcmTokens,
      'profileCompleted': profileCompleted,
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AppUserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    AppUserRole? role,
    String? careerId,
    int? semester,
    String? groupId,
    String? controlNumber,
    Map<String, String>? fcmTokens,
    bool? profileCompleted,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      careerId: careerId ?? this.careerId,
      semester: semester ?? this.semester,
      groupId: groupId ?? this.groupId,
      controlNumber: controlNumber ?? this.controlNumber,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
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

  static Map<String, String> _readStringMap(Object? value) {
    if (value is! Map) {
      return const {};
    }

    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
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
