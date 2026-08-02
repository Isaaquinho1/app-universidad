import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Issues and validates dynamic institutional student ID QR tokens.
class StudentIdQrRepository {
  const StudentIdQrRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  /// Issues a new 60-second token for the authenticated student.
  ///
  /// Issuing a token revokes any previous active token for that student.
  Future<StudentIdQrToken> issueToken() async {
    final response = await _supabaseClient.rpc('issue_student_id_qr_token');

    if (response is! Map) {
      throw StateError(
        'The student QR token RPC returned an invalid response.',
      );
    }

    return StudentIdQrToken.fromSupabase(Map<String, dynamic>.from(response));
  }

  /// Validates one scanned token using the protected server RPC.
  ///
  /// The authenticated account must have admin or superAdmin privileges.
  Future<StudentIdQrValidationResult> validateToken(String token) async {
    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      throw const FormatException('El código QR no contiene un token válido.');
    }

    final response = await _supabaseClient.rpc(
      'validate_student_id_qr_token',
      params: {'p_token': normalizedToken},
    );

    if (response is! Map) {
      throw StateError(
        'The student QR validation RPC returned an invalid response.',
      );
    }

    return StudentIdQrValidationResult.fromSupabase(
      Map<String, dynamic>.from(response),
    );
  }
}
