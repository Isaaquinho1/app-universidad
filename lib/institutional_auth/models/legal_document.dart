/// Versioned legal document required during account registration.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.title,
    required this.content,
    required this.status,
  });

  final String id;
  final String type;
  final String version;
  final String title;
  final String content;
  final String status;

  bool get isTerms => type == 'terms';

  bool get isPrivacy => type == 'privacy';

  bool get isDevelopment => status == 'development';

  factory LegalDocument.fromSupabase(Map<String, dynamic> row) {
    return LegalDocument(
      id: row['document_id'] as String? ?? '',
      type: row['document_type'] as String? ?? '',
      version: row['version'] as String? ?? '',
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      status: row['status'] as String? ?? '',
    );
  }
}
