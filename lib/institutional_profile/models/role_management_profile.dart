import 'app_user_role.dart';

/// Institutional account visible to a superAdmin during role management.
class RoleManagementProfile {
  const RoleManagementProfile({
    required this.id,
    required this.role,
    required this.accountType,
    required this.staffApprovalPending,
    required this.active,
    this.email,
    this.displayName,
    this.controlNumber,
    this.createdAt,
  });

  factory RoleManagementProfile.fromSupabase(Map<String, dynamic> row) {
    return RoleManagementProfile(
      id: row['id'] as String? ?? '',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      role: AppUserRole.fromValue(row['role'] as String?),
      accountType: row['account_type'] as String? ?? 'student',
      staffApprovalPending: row['staff_approval_pending'] as bool? ?? false,
      active: row['active'] as bool? ?? true,
      controlNumber: row['control_number'] as String?,
      createdAt: _readDateTime(row['created_at']),
    );
  }

  final String id;
  final String? email;
  final String? displayName;
  final AppUserRole role;
  final String accountType;
  final bool staffApprovalPending;
  final bool active;
  final String? controlNumber;
  final DateTime? createdAt;

  /// Existing superAdmin accounts are intentionally immutable in the
  /// mobile role-management flow.
  bool get canChangeRole => role != AppUserRole.superAdmin;

  /// Whether this account was registered as institutional staff.
  bool get isStaffAccount =>
      accountType == 'campusStaff' || accountType == 'tecnmStaff';
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
