import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user_role.dart';

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

  bool get isAdmin => role == AppUserRole.admin;

  bool get isSuperAdmin => role == AppUserRole.superAdmin;

  bool get canManageAnnouncements => role.canManageAnnouncements;

  bool get canManageAdmins => role.canManageAdmins;

  factory AppUserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return AppUserProfile.fromJson({
      ...data,
      'uid': data['uid'] ?? snapshot.id,
    });
  }

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      role: AppUserRole.fromValue(json['role'] as String?),
      careerId: json['careerId'] as String?,
      semester: json['semester'] as int?,
      groupId: json['groupId'] as String?,
      controlNumber: json['controlNumber'] as String?,
      fcmTokens: _readStringMap(json['fcmTokens']),
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: _readDateTime(json['updatedAt']),
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

  static Map<String, String> _readStringMap(Object? value) {
    if (value is! Map) {
      return const {};
    }

    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
