/// Server-side result of validating one dynamic student ID QR token.
class StudentIdQrValidationResult {
  const StudentIdQrValidationResult({
    required this.valid,
    required this.validatedAt,
    this.reason,
    this.studentId,
    this.displayName,
    this.controlNumber,
    this.careerId,
    this.semester,
    this.groupId,
    this.photoPath,
    this.issuedAt,
    this.expiresAt,
  });

  factory StudentIdQrValidationResult.fromSupabase(Map<String, dynamic> data) {
    final valid = data['valid'] as bool?;
    final validatedAt = DateTime.tryParse(
      data['validated_at']?.toString() ?? '',
    );

    if (valid == null || validatedAt == null) {
      throw const FormatException(
        'El servidor devolvió una validación QR incompleta.',
      );
    }

    return StudentIdQrValidationResult(
      valid: valid,
      reason: data['reason'] as String?,
      studentId: data['student_id'] as String?,
      displayName: data['display_name'] as String?,
      controlNumber: data['control_number'] as String?,
      careerId: data['career_id'] as String?,
      semester: (data['semester'] as num?)?.toInt(),
      groupId: data['group_id'] as String?,
      photoPath: data['photo_path'] as String?,
      issuedAt: _parseOptionalDate(data['issued_at']),
      expiresAt: _parseOptionalDate(data['expires_at']),
      validatedAt: validatedAt.toUtc(),
    );
  }

  final bool valid;
  final String? reason;

  final String? studentId;
  final String? displayName;
  final String? controlNumber;
  final String? careerId;
  final int? semester;
  final String? groupId;
  final String? photoPath;

  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime validatedAt;

  static DateTime? _parseOptionalDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }
}
