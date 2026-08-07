class AcademicSubtask {
  const AcademicSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AcademicSubtask.fromDatabase(Map<String, Object?> row) {
    return AcademicSubtask(
      id: row['id']! as String,
      taskId: row['task_id']! as String,
      title: row['title']! as String,
      isCompleted: (row['is_completed']! as int) == 1,
      position: row['position']! as int,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  AcademicSubtask copyWith({
    String? title,
    bool? isCompleted,
    int? position,
    DateTime? updatedAt,
  }) {
    return AcademicSubtask(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
