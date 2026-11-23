import 'package:conecta_itt/institutional_profile/models/student_academic_period_assignment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads academic history through the authorized Supabase RPC.
///
/// PostgreSQL verifies the caller's identity and permissions.
/// The underlying history table is not queried directly.
class StudentAcademicHistoryRepository {
  const StudentAcademicHistoryRepository({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const _rpcName = 'get_student_academic_period_history';

  /// Returns the history of the currently authenticated student.
  Future<List<StudentAcademicPeriodAssignment>> fetchMyAcademicHistory() async {
    _requireAuthenticatedUser();

    return _fetchHistory();
  }

  /// Returns the academic history of a selected student.
  ///
  /// Only authorized administrators can access other users'
  /// records. This permission is enforced by PostgreSQL.
  Future<List<StudentAcademicPeriodAssignment>>
  fetchStudentAcademicHistoryAsAdmin({required String userId}) async {
    _requireAuthenticatedUser();

    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Student ID cannot be empty.',
      );
    }

    return _fetchHistory(userId: normalizedUserId);
  }

  void _requireAuthenticatedUser() {
    if (_supabaseClient.auth.currentUser == null) {
      throw StateError(
        'Authentication is required to access academic history.',
      );
    }
  }

  Future<List<StudentAcademicPeriodAssignment>> _fetchHistory({
    String? userId,
  }) async {
    final response = await _supabaseClient.rpc(
      _rpcName,
      params: {'p_user_id': userId},
    );

    if (response is! List) {
      throw StateError('Academic history RPC returned an invalid response.');
    }

    return List<StudentAcademicPeriodAssignment>.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid academic history record.');
        }

        return StudentAcademicPeriodAssignment.fromSupabase(
          Map<String, dynamic>.from(item),
        );
      }),
    );
  }
}
