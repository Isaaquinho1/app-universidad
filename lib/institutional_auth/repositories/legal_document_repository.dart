import 'package:flutter/services.dart';
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
      throw StateError('Catálogo legal no disponible.');
    }

    final documents = response
        .whereType<Map>()
        .map(
          (row) => LegalDocument.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);

    const assets = <String, String>{
      'terms': 'assets/legal/terms.txt',
      'privacy': 'assets/legal/privacy.txt',
      'integral_notice': 'assets/legal/integral_notice.txt',
    };

    if (documents.length != assets.length ||
        documents.map((document) => document.type).toSet().length !=
            assets.length) {
      throw StateError('Se requieren los tres documentos legales.');
    }

    for (final document in documents) {
      final assetPath = assets[document.type];

      if (assetPath == null ||
          document.id.isEmpty ||
          document.version.isEmpty ||
          document.status != 'active') {
        throw StateError('Documentos legales pendientes de publicación.');
      }

      final bundledContent = await rootBundle.loadString(assetPath);

      if (bundledContent != document.content) {
        throw StateError(
          'El texto legal no coincide con la versión publicada.',
        );
      }
    }

    return documents;
  }
}
