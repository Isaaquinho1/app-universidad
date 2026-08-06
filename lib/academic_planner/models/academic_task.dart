import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';

class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.subjectId,
    this.categoryId,
    this.dueAt,
    this.reminderAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? subjectId;
  final String? categoryId;
  final DateTime? dueAt;
  final TaskPriority priority;
  final AcademicTaskStatus status;
  final DateTime? reminderAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == AcademicTaskStatus.completed;

  bool get isOverdue {
    final deadline = dueAt;
    return deadline != null &&
        !isCompleted &&
        deadline.isBefore(DateTime.now());
  }

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject_id': subjectId,
      'category_id': categoryId,
      'due_at': dueAt?.toIso8601String(),
      'priority': priority.databaseValue,
      'status': status.databaseValue,
      'reminder_at': reminderAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AcademicTask.fromDatabase(Map<String, Object?> row) {
    DateTime? parseNullable(Object? value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.parse(value);
    }

    return AcademicTask(
      id: row['id']! as String,
      title: row['title']! as String,
      description: row['description'] as String?,
      subjectId: row['subject_id'] as String?,
      categoryId: row['category_id'] as String?,
      dueAt: parseNullable(row['due_at']),
      priority: TaskPriority.fromDatabase(row['priority'] as String?),
      status: AcademicTaskStatus.fromDatabase(row['status'] as String?),
      reminderAt: parseNullable(row['reminder_at']),
      completedAt: parseNullable(row['completed_at']),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
