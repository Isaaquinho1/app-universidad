/// Academic placement recorded for one institutional period.
///
/// This is a snapshot of a student's academic placement,
/// not a replacement for the current institutional profile.
class StudentAcademicPeriodAssignment {
  const StudentAcademicPeriodAssignment({
    required this.academicPeriodId,
    required this.periodCode,
    required this.periodName,
    required this.careerId,
    required this.semester,
    required this.assignedAt,
    required this.updatedAt,
    this.groupId,
    this.startsOn,
    this.endsOn,
  });

  factory StudentAcademicPeriodAssignment.fromSupabase(
    Map<String, dynamic> row,
  ) {
    String requiredText(String key) {
      final value = row[key];

      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid academic history field: $key');
      }

      return value;
    }

    final semesterValue = row['semester'];

    final semester =
        semesterValue is int
            ? semesterValue
            : semesterValue is num
            ? semesterValue.toInt()
            : int.tryParse(semesterValue?.toString() ?? '');

    if (semester == null || semester < 1 || semester > 14) {
      throw const FormatException('Invalid academic history semester.');
    }

    DateTime parseRequiredDate(String key) {
      final parsed = DateTime.tryParse(requiredText(key));

      if (parsed == null) {
        throw FormatException('Invalid academic history date: $key');
      }

      return parsed;
    }

    DateTime? parseOptionalDate(String key) {
      final value = row[key];

      if (value == null) {
        return null;
      }

      if (value is! String) {
        throw FormatException('Invalid academic history date: $key');
      }

      final parsed = DateTime.tryParse(value);

      if (parsed == null) {
        throw FormatException('Invalid academic history date: $key');
      }

      return parsed;
    }

    final group = row['group_id'];

    if (group != null && group is! String) {
      throw const FormatException('Invalid academic history group.');
    }

    return StudentAcademicPeriodAssignment(
      academicPeriodId: requiredText('academic_period_id'),
      periodCode: requiredText('period_code'),
      periodName: requiredText('period_name'),
      careerId: requiredText('career_id'),
      semester: semester,
      groupId: group is String && group.trim().isNotEmpty ? group.trim() : null,
      startsOn: parseOptionalDate('starts_on'),
      endsOn: parseOptionalDate('ends_on'),
      assignedAt: parseRequiredDate('assigned_at'),
      updatedAt: parseRequiredDate('updated_at'),
    );
  }

  final String academicPeriodId;
  final String periodCode;
  final String periodName;
  final String careerId;
  final int semester;
  final String? groupId;

  final DateTime? startsOn;
  final DateTime? endsOn;

  final DateTime assignedAt;
  final DateTime updatedAt;

  bool get hasGroup => groupId != null;
}
