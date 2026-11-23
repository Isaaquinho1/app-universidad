import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invokes one Supabase RPC with named parameters.
typedef AcademicOfferingsRpcInvoker =
    Future<dynamic> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );

/// Administrative operations for groups and academic-period offerings.
///
/// Authorization, consistency and audit rules remain enforced by
/// PostgreSQL. Client-side validation is not a security boundary.
class AdminAcademicOfferingsRepository {
  AdminAcademicOfferingsRepository({required SupabaseClient supabaseClient})
    : _invoke = ((name, params) => supabaseClient.rpc(name, params: params));

  /// Allows deterministic unit tests without network or database access.
  AdminAcademicOfferingsRepository.forTesting({
    required AcademicOfferingsRpcInvoker invoke,
  }) : _invoke = invoke;

  final AcademicOfferingsRpcInvoker _invoke;

  static String _requiredText(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Cannot be empty');
    }

    return normalized;
  }

  /// Lists all known groups, including those not yet offered.
  Future<List<AdminAcademicGroupOffering>> fetchOfferings({
    required String periodCode,
    String? careerId,
    int? semester,
  }) async {
    final normalizedPeriod = _requiredText(periodCode, 'periodCode');

    final normalizedCareer =
        careerId == null
            ? null
            : _requiredText(careerId, 'careerId').toLowerCase();

    if (semester != null && (semester < 1 || semester > 14)) {
      throw ArgumentError.value(
        semester,
        'semester',
        'Must be between 1 and 14',
      );
    }

    final response = await _invoke('admin_get_academic_group_offerings', {
      'p_period_code': normalizedPeriod,
      'p_career_id': normalizedCareer,
      'p_semester': semester,
    });

    if (response is! List) {
      throw const FormatException('Unexpected academic offerings response');
    }

    return response
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Unexpected academic offering row');
          }

          return AdminAcademicGroupOffering.fromSupabase(
            Map<String, dynamic>.from(row),
          );
        })
        .toList(growable: false);
  }

  /// Creates an institutional group, initially inactive.
  ///
  /// The database determines the group ID and validates the career,
  /// semester, parallel and caller's administrative permissions.
  Future<String> createGroup({
    required String careerId,
    required int semester,
    required int parallel,
  }) async {
    final normalizedCareer = _requiredText(careerId, 'careerId').toLowerCase();

    if (semester < 1 || semester > 9) {
      throw ArgumentError.value(
        semester,
        'semester',
        'Ordinary semesters must be between 1 and 9',
      );
    }

    if (parallel < 1 || parallel > 9) {
      throw ArgumentError.value(
        parallel,
        'parallel',
        'Must be between 1 and 9',
      );
    }

    final response = await _invoke('admin_create_academic_group', {
      'p_career_id': normalizedCareer,
      'p_semester': semester,
      'p_parallel': parallel,
    });

    if (response is! String || response.trim().isEmpty) {
      throw const FormatException('Unexpected group creation response');
    }

    return response.trim();
  }

  /// Activates or deactivates an institutional academic group.
  ///
  /// PostgreSQL enforces administrative authorization, offering
  /// consistency, concurrency protection and audit logging.
  Future<void> setGroupActive({
    required String groupId,
    required bool active,
  }) async {
    final normalizedGroup = _requiredText(groupId, 'groupId');

    await _invoke('admin_set_academic_group_active', {
      'p_group_id': normalizedGroup,
      'p_active': active,
    });
  }

  /// Registers, enables or disables a group's period offering.
  ///
  /// Does not delete the group or student history.
  Future<void> setGroupOffering({
    required String periodCode,
    required String groupId,
    required bool isOffered,
  }) async {
    final normalizedPeriod = _requiredText(periodCode, 'periodCode');

    final normalizedGroup = _requiredText(groupId, 'groupId');

    await _invoke('admin_set_academic_group_offering', {
      'p_period_code': normalizedPeriod,
      'p_group_id': normalizedGroup,
      'p_is_offered': isOffered,
    });
  }
}
