/// Administrative view of a group offering for one academic period.
///
/// This model represents the result of
/// admin_get_academic_group_offerings.
class AdminAcademicGroupOffering {
  const AdminAcademicGroupOffering({
    required this.academicPeriodId,
    required this.periodCode,
    required this.periodName,
    required this.periodStartsOn,
    required this.periodEndsOn,
    required this.groupId,
    required this.groupName,
    required this.careerId,
    required this.semester,
    required this.groupActive,
    required this.offeringRegistered,
    required this.isOffered,
    required this.offeringUpdatedAt,
  });

  final String academicPeriodId;
  final String periodCode;
  final String periodName;
  final DateTime periodStartsOn;
  final DateTime periodEndsOn;

  final String groupId;
  final String groupName;
  final String? careerId;
  final int? semester;

  final bool groupActive;
  final bool offeringRegistered;
  final bool isOffered;
  final DateTime? offeringUpdatedAt;

  bool get isUnconfigured => !offeringRegistered;

  bool get isEnabled => offeringRegistered && isOffered;

  bool get isDisabled => offeringRegistered && !isOffered;

  factory AdminAcademicGroupOffering.fromSupabase(Map<String, dynamic> row) {
    String requiredString(String key) {
      final value = row[key];

      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid academic offering field: $key');
      }

      return value.trim();
    }

    bool requiredBool(String key) {
      final value = row[key];

      if (value is! bool) {
        throw FormatException('Invalid academic offering field: $key');
      }

      return value;
    }

    DateTime requiredDate(String key) {
      final value = row[key];
      final parsed = value is String ? DateTime.tryParse(value) : null;

      if (parsed == null) {
        throw FormatException('Invalid academic offering date: $key');
      }

      return parsed;
    }

    DateTime? optionalDate(String key) {
      final value = row[key];

      if (value == null) {
        return null;
      }

      if (value is! String) {
        throw FormatException('Invalid academic offering date: $key');
      }

      final parsed = DateTime.tryParse(value);

      if (parsed == null) {
        throw FormatException('Invalid academic offering date: $key');
      }

      return parsed;
    }

    final semesterValue = row['semester'];

    int? parsedSemester;
    if (semesterValue != null) {
      if (semesterValue is int) {
        parsedSemester = semesterValue;
      } else if (semesterValue is String) {
        parsedSemester = int.tryParse(semesterValue);
      }

      if (parsedSemester == null || parsedSemester < 1 || parsedSemester > 14) {
        throw const FormatException('Invalid academic offering semester');
      }
    }

    final offeringRegistered = requiredBool('offering_registered');

    final isOffered = requiredBool('is_offered');

    if (!offeringRegistered && isOffered) {
      throw const FormatException('An unregistered offering cannot be enabled');
    }

    final offeringUpdatedAt = optionalDate('offering_updated_at');

    if (!offeringRegistered && offeringUpdatedAt != null) {
      throw const FormatException(
        'An unregistered offering cannot have an update date',
      );
    }

    final careerValue = row['career_id'];

    if (careerValue != null && careerValue is! String) {
      throw const FormatException('Invalid academic offering career');
    }

    return AdminAcademicGroupOffering(
      academicPeriodId: requiredString('academic_period_id'),
      periodCode: requiredString('period_code'),
      periodName: requiredString('period_name'),
      periodStartsOn: requiredDate('period_starts_on'),
      periodEndsOn: requiredDate('period_ends_on'),
      groupId: requiredString('group_id'),
      groupName: requiredString('group_name'),
      careerId: careerValue as String?,
      semester: parsedSemester,
      groupActive: requiredBool('group_active'),
      offeringRegistered: offeringRegistered,
      isOffered: isOffered,
      offeringUpdatedAt: offeringUpdatedAt,
    );
  }
}
