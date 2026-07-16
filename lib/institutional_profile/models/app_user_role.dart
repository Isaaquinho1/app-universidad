/// Institutional authorization roles used by Conecta ITT.
enum AppUserRole {
  student,
  teacher,
  admin,
  superAdmin;

  /// Database representation of the role.
  String get value {
    switch (this) {
      case AppUserRole.student:
        return 'student';
      case AppUserRole.teacher:
        return 'teacher';
      case AppUserRole.admin:
        return 'admin';
      case AppUserRole.superAdmin:
        return 'superAdmin';
    }
  }

  /// Whether this role can create and manage institutional announcements.
  bool get canManageAnnouncements =>
      this == AppUserRole.admin || this == AppUserRole.superAdmin;

  /// Whether this role can administer other privileged accounts.
  bool get canManageAdmins => this == AppUserRole.superAdmin;

  /// Converts the persisted role value into an application role.
  static AppUserRole fromValue(String? value) {
    switch (value) {
      case 'teacher':
        return AppUserRole.teacher;
      case 'admin':
        return AppUserRole.admin;
      case 'superAdmin':
        return AppUserRole.superAdmin;
      case 'student':
      default:
        return AppUserRole.student;
    }
  }
}
