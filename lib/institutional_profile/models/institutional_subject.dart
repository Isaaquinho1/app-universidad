class InstitutionalSubject {
  const InstitutionalSubject({
    required this.id,
    required this.name,
    required this.active,
    this.code,
  });

  factory InstitutionalSubject.fromSupabase(Map<String, dynamic> row) {
    return InstitutionalSubject(
      id: row['id'] as String,
      name: row['name'] as String,
      code: row['code'] as String?,
      active: row['active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String? code;
  final bool active;

  String get displayName {
    final normalizedCode = code?.trim();

    if (normalizedCode == null || normalizedCode.isEmpty) {
      return name;
    }

    return '$normalizedCode · $name';
  }
}
