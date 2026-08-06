class AcademicSubject {
  const AcademicSubject({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.code,
    this.teacherName,
    this.notes,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String? code;
  final String? teacherName;
  final int colorValue;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  AcademicSubject copyWith({
    String? id,
    String? name,
    String? code,
    String? teacherName,
    int? colorValue,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicSubject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      teacherName: teacherName ?? this.teacherName,
      colorValue: colorValue ?? this.colorValue,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'teacher_name': teacherName,
      'color_value': colorValue,
      'notes': notes,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AcademicSubject.fromDatabase(Map<String, Object?> row) {
    return AcademicSubject(
      id: row['id']! as String,
      name: row['name']! as String,
      code: row['code'] as String?,
      teacherName: row['teacher_name'] as String?,
      colorValue: row['color_value']! as int,
      notes: row['notes'] as String?,
      isArchived: (row['is_archived']! as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
