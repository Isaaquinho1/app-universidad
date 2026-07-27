/// Academic group available for institutional profile segmentation.
class AcademicGroup {
  const AcademicGroup({
    required this.id,
    required this.careerId,
    required this.name,
    required this.semester,
  });

  final String id;
  final String careerId;
  final String name;
  final int semester;

  factory AcademicGroup.fromSupabase(Map<String, dynamic> row) {
    final semesterValue = row['semester'];

    return AcademicGroup(
      id: row['id'] as String? ?? '',
      careerId: row['career_id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      semester:
          semesterValue is num
              ? semesterValue.toInt()
              : int.tryParse(semesterValue?.toString() ?? '') ?? 0,
    );
  }
}
