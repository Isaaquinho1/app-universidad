class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    this.iconCodePoint,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final int? iconCodePoint;
  final bool isSystem;
  final DateTime createdAt;

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
      'is_system': isSystem ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TaskCategory.fromDatabase(Map<String, Object?> row) {
    return TaskCategory(
      id: row['id']! as String,
      name: row['name']! as String,
      colorValue: row['color_value']! as int,
      iconCodePoint: row['icon_code_point'] as int?,
      isSystem: (row['is_system']! as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }
}
