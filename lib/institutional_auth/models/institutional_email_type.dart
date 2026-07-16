/// Institutional account category inferred from an email address.
enum InstitutionalEmailType {
  student,
  campusStaff,
  tecnmStaff,
  invalid;

  bool get isValid => this != InstitutionalEmailType.invalid;

  bool get isStudent => this == InstitutionalEmailType.student;

  bool get isStaff =>
      this == InstitutionalEmailType.campusStaff ||
      this == InstitutionalEmailType.tecnmStaff;
}
