import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AcademicSubtaskRepository {
  AcademicSubtaskRepository({AcademicDatabase? academicDatabase, Uuid? uuid})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AcademicDatabase _academicDatabase;
  final Uuid _uuid;

  Future<List<AcademicSubtask>> getForTask(String taskId) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'academic_subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'position ASC, created_at ASC',
    );

    return rows.map(AcademicSubtask.fromDatabase).toList(growable: false);
  }

  Future<AcademicSubtask> create({
    required String taskId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'La subtarea requiere un título.',
      );
    }

    final database = await _academicDatabase.database;

    final taskExists =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COUNT(*)
            FROM academic_tasks
            WHERE id = ?
            ''',
            [taskId],
          ),
        ) ==
        1;

    if (!taskExists) {
      throw StateError(
        'No se encontró la tarea a la que pertenece la subtarea.',
      );
    }

    final nextPosition =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''
            SELECT COALESCE(MAX(position), -1) + 1
            FROM academic_subtasks
            WHERE task_id = ?
            ''',
            [taskId],
          ),
        ) ??
        0;

    final now = DateTime.now();

    final subtask = AcademicSubtask(
      id: _uuid.v4(),
      taskId: taskId,
      title: normalizedTitle,
      isCompleted: false,
      position: nextPosition,
      createdAt: now,
      updatedAt: now,
    );

    await database.insert(
      'academic_subtasks',
      subtask.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return subtask;
  }

  Future<AcademicSubtask> updateTitle({
    required AcademicSubtask subtask,
    required String title,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'La subtarea requiere un título.',
      );
    }

    final updated = subtask.copyWith(
      title: normalizedTitle,
      updatedAt: DateTime.now(),
    );

    await _update(updated);

    return updated;
  }

  Future<AcademicSubtask> setCompleted({
    required AcademicSubtask subtask,
    required bool isCompleted,
  }) async {
    final updated = subtask.copyWith(
      isCompleted: isCompleted,
      updatedAt: DateTime.now(),
    );

    await _update(updated);

    return updated;
  }

  Future<AcademicSubtask> toggleCompleted(AcademicSubtask subtask) {
    return setCompleted(subtask: subtask, isCompleted: !subtask.isCompleted);
  }

  Future<void> reorder({
    required String taskId,
    required List<AcademicSubtask> subtasks,
  }) async {
    final database = await _academicDatabase.database;

    for (final subtask in subtasks) {
      if (subtask.taskId != taskId) {
        throw ArgumentError(
          'Todas las subtareas deben pertenecer a la misma tarea.',
        );
      }
    }

    await database.transaction((transaction) async {
      final now = DateTime.now().toIso8601String();

      for (var index = 0; index < subtasks.length; index++) {
        final affectedRows = await transaction.update(
          'academic_subtasks',
          {'position': index, 'updated_at': now},
          where: 'id = ? AND task_id = ?',
          whereArgs: [subtasks[index].id, taskId],
        );

        if (affectedRows != 1) {
          throw StateError('No se pudo reordenar una de las subtareas.');
        }
      }
    });
  }

  Future<void> delete(String id) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.delete(
      'academic_subtasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la subtarea indicada.');
    }
  }

  Future<void> _update(AcademicSubtask subtask) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.update(
      'academic_subtasks',
      subtask.toDatabase(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la subtarea indicada.');
    }
  }
}
