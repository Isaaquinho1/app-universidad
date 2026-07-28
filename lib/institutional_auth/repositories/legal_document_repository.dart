import 'package:conecta_itt/institutional_auth/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Retrieves the current legal documents required during registration.
class LegalDocumentRepository {
  const LegalDocumentRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  Future<List<LegalDocument>> fetchRegistrationDocuments() async {
    final response = await _supabaseClient.rpc(
      'get_registration_legal_documents',
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => LegalDocument.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .where(
          (document) =>
              document.id.isNotEmpty &&
              document.version.isNotEmpty &&
              (document.isTerms || document.isPrivacy),
        )
        .toList(growable: false);
  }
}
