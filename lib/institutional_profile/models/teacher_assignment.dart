import 'package:conecta_itt/institutional_profile/models/teacher_assignment_session.dart';

class TeacherAssignment {
  const TeacherAssignment({
    required this.id,
    required this.active,
    required this.teacherId,
    required this.subjectId,
    required this.subjectName,
    required this.academicGroupId,
    required this.academicPeriodId,
    required this.academicPeriodName,
    required this.sessions,
    this.teacherEmail,
    this.teacherDisplayName,
    this.subjectCode,
    this.subjectActive = true,
    this.groupName,
    this.careerId,
    this.careerName,
    this.semester,
    this.academicPeriodCode,
    this.periodStartsOn,
    this.periodEndsOn,
    this.periodIsActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TeacherAssignment.fromSupabase(Map<String, dynamic> row) {
    final rawSessions = row['sessions'];

    final sessions =
        rawSessions is List
            ? rawSessions
                .whereType<Map>()
                .map(
                  (item) => TeacherAssignmentSession.fromSupabase(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
            : const <TeacherAssignmentSession>[];

    return TeacherAssignment(
      id: row['assignment_id'] as String,
      active: row['assignment_active'] as bool? ?? true,
      teacherId: row['teacher_id'] as String,
      teacherEmail: row['teacher_email'] as String?,
      teacherDisplayName: row['teacher_display_name'] as String?,
      subjectId: row['subject_id'] as String,
      subjectCode: row['subject_code'] as String?,
      subjectName: row['subject_name'] as String,
      subjectActive: row['subject_active'] as bool? ?? true,
      academicGroupId: row['academic_group_id'] as String,
      groupName: row['group_name'] as String?,
      careerId: row['career_id'] as String?,
      careerName: row['career_name'] as String?,
      semester: (row['semester'] as num?)?.toInt(),
      academicPeriodId: row['academic_period_id'] as String,
      academicPeriodCode: row['academic_period_code'] as String?,
      academicPeriodName: row['academic_period_name'] as String,
      periodStartsOn: row['period_starts_on'] as String?,
      periodEndsOn: row['period_ends_on'] as String?,
      periodIsActive: row['period_is_active'] as bool?,
      sessions: sessions,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  final String id;
  final bool active;

  final String teacherId;
  final String? teacherEmail;
  final String? teacherDisplayName;

  final String subjectId;
  final String? subjectCode;
  final String subjectName;
  final bool subjectActive;

  final String academicGroupId;
  final String? groupName;
  final String? careerId;
  final String? careerName;
  final int? semester;

  final String academicPeriodId;
  final String? academicPeriodCode;
  final String academicPeriodName;
  final String? periodStartsOn;
  final String? periodEndsOn;
  final bool? periodIsActive;

  final List<TeacherAssignmentSession> sessions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get teacherName {
    final normalizedName = teacherDisplayName?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedEmail = teacherEmail?.trim();

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }

    return 'Docente institucional';
  }

  String get subjectDisplayName {
    final normalizedCode = subjectCode?.trim();

    if (normalizedCode == null || normalizedCode.isEmpty) {
      return subjectName;
    }

    return '$normalizedCode · $subjectName';
  }

  String get groupDisplayName {
    final normalizedName = groupName?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    return academicGroupId;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
