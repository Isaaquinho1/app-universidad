class TeacherProfileSummary {
  const TeacherProfileSummary({
    required this.id,
    required this.active,
    this.email,
    this.displayName,
    this.accountType,
  });

  factory TeacherProfileSummary.fromSupabase(Map<String, dynamic> row) {
    return TeacherProfileSummary(
      id: row['id'] as String,
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      accountType: row['account_type'] as String?,
      active: row['active'] as bool? ?? true,
    );
  }

  final String id;
  final String? email;
  final String? displayName;
  final String? accountType;
  final bool active;

  String get preferredName {
    final normalizedName = displayName?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedEmail = email?.trim();

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }

    return 'Docente institucional';
  }
}
