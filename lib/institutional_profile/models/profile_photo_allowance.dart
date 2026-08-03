class ProfilePhotoAllowance {
  const ProfilePhotoAllowance({
    required this.academicPeriodId,
    required this.academicPeriodCode,
    required this.academicPeriodName,
    required this.baseLimit,
    required this.extraChanges,
    required this.totalLimit,
    required this.usedChanges,
    required this.remainingChanges,
    required this.hasPendingSubmission,
    required this.hasInitialSubmission,
    required this.canSubmit,
  });

  factory ProfilePhotoAllowance.fromJson(Map<String, dynamic> json) {
    return ProfilePhotoAllowance(
      academicPeriodId: json['academic_period_id'] as String,
      academicPeriodCode: json['academic_period_code'] as String,
      academicPeriodName: json['academic_period_name'] as String,
      baseLimit: (json['base_limit'] as num).toInt(),
      extraChanges: (json['extra_changes'] as num).toInt(),
      totalLimit: (json['total_limit'] as num).toInt(),
      usedChanges: (json['used_changes'] as num).toInt(),
      remainingChanges: (json['remaining_changes'] as num).toInt(),
      hasPendingSubmission: json['has_pending_submission'] as bool? ?? false,
      hasInitialSubmission: json['has_initial_submission'] as bool? ?? false,
      canSubmit: json['can_submit'] as bool? ?? false,
    );
  }

  final String academicPeriodId;
  final String academicPeriodCode;
  final String academicPeriodName;

  final int baseLimit;
  final int extraChanges;
  final int totalLimit;
  final int usedChanges;
  final int remainingChanges;

  final bool hasPendingSubmission;
  final bool hasInitialSubmission;
  final bool canSubmit;
}
