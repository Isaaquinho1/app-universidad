import 'package:conecta_itt/institutional_profile/models/models.dart';

/// Defines the audience targeted by an institutional announcement.
class AnnouncementTarget {
  const AnnouncementTarget({
    this.allUsers = false,
    this.roles = const {},
    this.careerIds = const {},
    this.semesters = const {},
    this.groupIds = const {},
    this.userUids = const {},
  });

  /// Creates a target that includes every active user.
  const AnnouncementTarget.all()
    : allUsers = true,
      roles = const {},
      careerIds = const {},
      semesters = const {},
      groupIds = const {},
      userUids = const {};

  /// Whether the announcement is intended for every active user.
  final bool allUsers;

  /// Roles included in the audience.
  final Set<AppUserRole> roles;

  /// Institutional career identifiers included in the audience.
  final Set<String> careerIds;

  /// Academic semesters included in the audience.
  final Set<int> semesters;

  /// Institutional group identifiers included in the audience.
  final Set<String> groupIds;

  /// Specific authenticated users included directly in the audience.
  final Set<String> userUids;

  /// Whether this target contains no effective audience.
  bool get isEmpty =>
      !allUsers &&
      roles.isEmpty &&
      careerIds.isEmpty &&
      semesters.isEmpty &&
      groupIds.isEmpty &&
      userUids.isEmpty;

  /// Whether at least one audience criterion is configured.
  bool get isNotEmpty => !isEmpty;

  /// Returns whether [profile] belongs to this announcement audience.
  ///
  /// Every non-empty criterion acts as an AND condition between dimensions.
  /// Values inside the same dimension act as OR conditions.
  bool matches(AppUserProfile profile) {
    if (!profile.active) {
      return false;
    }

    if (allUsers) {
      return true;
    }

    if (roles.isNotEmpty && !roles.contains(profile.role)) {
      return false;
    }

    if (careerIds.isNotEmpty &&
        (profile.careerId == null || !careerIds.contains(profile.careerId))) {
      return false;
    }

    if (semesters.isNotEmpty &&
        (profile.semester == null || !semesters.contains(profile.semester))) {
      return false;
    }

    if (groupIds.isNotEmpty &&
        (profile.groupId == null || !groupIds.contains(profile.groupId))) {
      return false;
    }

    return isNotEmpty;
  }

  factory AnnouncementTarget.fromJson(Map<String, dynamic> json) {
    return AnnouncementTarget(
      allUsers:
          json['allUsers'] as bool? ?? json['all_users'] as bool? ?? false,
      roles: _readStringSet(json['roles']).map(AppUserRole.fromValue).toSet(),
      careerIds: _readStringSet(json['careerIds'] ?? json['career_ids']),
      semesters: _readIntSet(json['semesters']),
      groupIds: _readStringSet(json['groupIds'] ?? json['group_ids']),
      userUids: _readStringSet(json['userUids'] ?? json['user_ids']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allUsers': allUsers,
      'roles': roles.map((role) => role.value).toList(growable: false),
      'careerIds': careerIds.toList(growable: false),
      'semesters': semesters.toList(growable: false),
      'groupIds': groupIds.toList(growable: false),
      'userUids': userUids.toList(growable: false),
    };
  }

  AnnouncementTarget copyWith({
    bool? allUsers,
    Set<AppUserRole>? roles,
    Set<String>? careerIds,
    Set<int>? semesters,
    Set<String>? groupIds,
    Set<String>? userUids,
  }) {
    return AnnouncementTarget(
      allUsers: allUsers ?? this.allUsers,
      roles: roles ?? this.roles,
      careerIds: careerIds ?? this.careerIds,
      semesters: semesters ?? this.semesters,
      groupIds: groupIds ?? this.groupIds,
      userUids: userUids ?? this.userUids,
    );
  }

  static Set<String> _readStringSet(Object? value) {
    if (value is! Iterable) {
      return const {};
    }

    return value
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static Set<int> _readIntSet(Object? value) {
    if (value is! Iterable) {
      return const {};
    }

    return value
        .map((item) {
          if (item is int) {
            return item;
          }

          return int.tryParse(item.toString());
        })
        .whereType<int>()
        .toSet();
  }
}
