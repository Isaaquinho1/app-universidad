/// Student profile exposed to the administrative academic-management flow.
///
/// This model intentionally contains only the institutional information
/// required to review and update academic placement.
class AdminStudentAcademicProfile {
  const AdminStudentAcademicProfile({
    required this.id,
    required this.active,
    required this.profileCompleted,
    this.email,
    this.displayName,
    this.controlNumber,
    this.careerId,
    this.semester,
    this.groupId,
  });

  factory AdminStudentAcademicProfile.fromSupabase(Map<String, dynamic> row) {
    final semesterValue = row['semester'];

    return AdminStudentAcademicProfile(
      id: row['id'] as String? ?? '',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      controlNumber: row['control_number'] as String?,
      careerId: row['career_id'] as String?,
      semester:
          semesterValue is num
              ? semesterValue.toInt()
              : int.tryParse(semesterValue?.toString() ?? ''),
      groupId: row['group_id'] as String?,
      active: row['active'] as bool? ?? true,
      profileCompleted: row['profile_completed'] as bool? ?? false,
    );
  }

  final String id;
  final String? email;
  final String? displayName;
  final String? controlNumber;
  final String? careerId;
  final int? semester;
  final String? groupId;
  final bool active;
  final bool profileCompleted;

  String get preferredName {
    final normalizedName = displayName?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedEmail = email?.trim();

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }

    return 'Estudiante institucional';
  }
}
