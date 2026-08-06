import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AcademicTaskRepository {
  AcademicTaskRepository({AcademicDatabase? academicDatabase, Uuid? uuid})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AcademicDatabase _academicDatabase;
  final Uuid _uuid;

  Future<AcademicTask> create({
    required String title,
    String? description,
    String? subjectId,
    String? categoryId,
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.medium,
    DateTime? reminderAt,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'La tarea requiere un título.');
    }

    if (reminderAt != null && dueAt != null && reminderAt.isAfter(dueAt)) {
      throw ArgumentError(
        'El recordatorio no puede programarse después del vencimiento.',
      );
    }

    final now = DateTime.now();

    final task = AcademicTask(
      id: _uuid.v4(),
      title: normalizedTitle,
      description: _normalizeOptional(description),
      subjectId: subjectId,
      categoryId: categoryId,
      dueAt: dueAt,
      priority: priority,
      status: AcademicTaskStatus.pending,
      reminderAt: reminderAt,
      createdAt: now,
      updatedAt: now,
    );

    final database = await _academicDatabase.database;
    await database.insert(
      'academic_tasks',
      task.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return task;
  }

  Future<List<AcademicTask>> getAll({bool includeArchived = false}) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'academic_tasks',
      where: includeArchived ? null : 'status != ?',
      whereArgs:
          includeArchived ? null : [AcademicTaskStatus.archived.databaseValue],
      orderBy: '''
        CASE WHEN due_at IS NULL THEN 1 ELSE 0 END,
        due_at ASC,
        created_at DESC
      ''',
    );

    return rows.map(AcademicTask.fromDatabase).toList(growable: false);
  }

  Future<List<AcademicTask>> getByStatus(AcademicTaskStatus status) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'academic_tasks',
      where: 'status = ?',
      whereArgs: [status.databaseValue],
      orderBy: 'due_at ASC, created_at DESC',
    );

    return rows.map(AcademicTask.fromDatabase).toList(growable: false);
  }

  Future<List<AcademicTask>> getPending({DateTime? dueBefore}) async {
    final database = await _academicDatabase.database;

    final pendingStatuses = [
      AcademicTaskStatus.pending.databaseValue,
      AcademicTaskStatus.inProgress.databaseValue,
    ];

    final clauses = <String>['status IN (?, ?)'];

    final arguments = <Object?>[...pendingStatuses];

    if (dueBefore != null) {
      clauses.add('due_at IS NOT NULL');
      clauses.add('due_at <= ?');
      arguments.add(dueBefore.toIso8601String());
    }

    final rows = await database.query(
      'academic_tasks',
      where: clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: '''
        CASE WHEN due_at IS NULL THEN 1 ELSE 0 END,
        due_at ASC
      ''',
    );

    return rows.map(AcademicTask.fromDatabase).toList(growable: false);
  }

  Future<List<AcademicTask>> getOverdue({DateTime? reference}) async {
    final database = await _academicDatabase.database;
    final now = reference ?? DateTime.now();

    final rows = await database.query(
      'academic_tasks',
      where: '''
        due_at IS NOT NULL
        AND due_at < ?
        AND status NOT IN (?, ?)
      ''',
      whereArgs: [
        now.toIso8601String(),
        AcademicTaskStatus.completed.databaseValue,
        AcademicTaskStatus.archived.databaseValue,
      ],
      orderBy: 'due_at ASC',
    );

    return rows.map(AcademicTask.fromDatabase).toList(growable: false);
  }

  Future<AcademicTask> update(AcademicTask task) async {
    final normalizedTitle = task.title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(task.title, 'title');
    }

    if (task.reminderAt != null &&
        task.dueAt != null &&
        task.reminderAt!.isAfter(task.dueAt!)) {
      throw ArgumentError(
        'El recordatorio no puede programarse después del vencimiento.',
      );
    }

    final completedAt =
        task.status == AcademicTaskStatus.completed
            ? task.completedAt ?? DateTime.now()
            : null;

    final updated = AcademicTask(
      id: task.id,
      title: normalizedTitle,
      description: _normalizeOptional(task.description),
      subjectId: task.subjectId,
      categoryId: task.categoryId,
      dueAt: task.dueAt,
      priority: task.priority,
      status: task.status,
      reminderAt: task.reminderAt,
      completedAt: completedAt,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );

    final database = await _academicDatabase.database;
    final affectedRows = await database.update(
      'academic_tasks',
      updated.toDatabase(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la tarea indicada.');
    }

    return updated;
  }

  Future<AcademicTask> updateStatus({
    required AcademicTask task,
    required AcademicTaskStatus status,
  }) {
    return update(
      AcademicTask(
        id: task.id,
        title: task.title,
        description: task.description,
        subjectId: task.subjectId,
        categoryId: task.categoryId,
        dueAt: task.dueAt,
        priority: task.priority,
        status: status,
        reminderAt: task.reminderAt,
        completedAt:
            status == AcademicTaskStatus.completed
                ? task.completedAt ?? DateTime.now()
                : null,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      ),
    );
  }

  Future<void> delete(String id) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.delete(
      'academic_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la tarea indicada.');
    }
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
