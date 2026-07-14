enum AppUserRole {
  student,
  admin,
  superAdmin;

  String get value {
    switch (this) {
      case AppUserRole.student:
        return 'student';
      case AppUserRole.admin:
        return 'admin';
      case AppUserRole.superAdmin:
        return 'superAdmin';
    }
  }

  bool get canManageAnnouncements =>
      this == AppUserRole.admin || this == AppUserRole.superAdmin;

  bool get canManageAdmins => this == AppUserRole.superAdmin;

  static AppUserRole fromValue(String? value) {
    switch (value) {
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
