import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_form_sheet.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Guarda una tarea y sus subtareas como una única operación SQLite.
///
/// No programa ni cancela notificaciones.
class AcademicTaskAtomicSaveService {
  AcademicTaskAtomicSaveService({
    required AcademicAccountScope account,
    Uuid uuid = const Uuid(),
  }) : _account = account,
       _uuid = uuid;

  final AcademicAccountScope _account;
  final Uuid _uuid;

  Future<AcademicTask> save({
    required AcademicTaskFormData form,
    AcademicTask? previousTask,
    List<AcademicSubtask>? originalSubtasks,
  }) {
    final title = form.title.trim();
    final description = form.description?.trim();

    if (title.isEmpty) {
      throw ArgumentError.value(
        form.title,
        'title',
        'La tarea requiere un título.',
      );
    }

    if (form.reminderAt != null &&
        form.dueAt != null &&
        form.reminderAt!.isAfter(form.dueAt!)) {
      throw ArgumentError(
        'El recordatorio no puede programarse después del vencimiento.',
      );
    }

    final desiredIds = <String>{};

    for (final subtask in form.subtasks) {
      if (subtask.title.trim().isEmpty) {
        throw ArgumentError('Las subtareas requieren un título.');
      }

      if (!desiredIds.add(subtask.id)) {
        throw StateError('El formulario contiene subtareas duplicadas.');
      }
    }

    return _account.runTransaction((transaction) async {
      if (previousTask != null) {
        final storedRows = await transaction.query(
          'academic_tasks',
          columns: ['updated_at'],
          where: 'id = ?',
          whereArgs: [previousTask.id],
          limit: 1,
        );

        if (storedRows.isEmpty) {
          throw StateError('La tarea ya no existe.');
        }

        final storedVersion = storedRows.single['updated_at'];

        if (storedVersion != previousTask.updatedAt.toIso8601String()) {
          throw StateError(
            'La tarea fue modificada después de abrir el formulario.',
          );
        }
      }

      if (previousTask != null) {
        if (originalSubtasks == null) {
          throw StateError('La edición requiere las subtareas originales.');
        }

        final currentRows = await transaction.query(
          'academic_subtasks',
          where: 'task_id = ?',
          whereArgs: [previousTask.id],
        );

        final currentSubtasks = currentRows
            .map(AcademicSubtask.fromDatabase)
            .toList(growable: false);

        if (!_sameSubtaskSnapshot(originalSubtasks, currentSubtasks)) {
          throw StateError(
            'Las subtareas fueron modificadas después '
            'de abrir el formulario.',
          );
        }
      }

      final currentTime = DateTime.now();
      final previousVersion = previousTask?.updatedAt;

      final now =
          previousVersion != null && !currentTime.isAfter(previousVersion)
              ? previousVersion.add(const Duration(microseconds: 1))
              : currentTime;

      final task = AcademicTask(
        id: previousTask?.id ?? _uuid.v4(),
        title: title,
        description:
            description == null || description.isEmpty ? null : description,
        subjectId: form.subjectId,
        categoryId: form.categoryId,
        dueAt: form.dueAt,
        priority: form.priority,
        status: previousTask == null ? AcademicTaskStatus.pending : form.status,
        reminderAt: form.reminderAt,
        completedAt:
            previousTask != null && form.status == AcademicTaskStatus.completed
                ? previousTask.completedAt ?? now
                : null,
        createdAt: previousTask?.createdAt ?? now,
        updatedAt: now,
      );

      if (previousTask == null) {
        await transaction.insert(
          'academic_tasks',
          task.toDatabase(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      } else {
        final affected = await transaction.update(
          'academic_tasks',
          task.toDatabase(),
          where: 'id = ? AND updated_at = ?',
          whereArgs: [task.id, previousTask.updatedAt.toIso8601String()],
        );

        if (affected != 1) {
          throw StateError(
            'La tarea cambió antes de completar la actualización.',
          );
        }
      }

      await _saveSubtasks(transaction, task.id, form.subtasks, now);

      return task;
    });
  }

  bool _sameSubtaskSnapshot(
    List<AcademicSubtask> original,
    List<AcademicSubtask> current,
  ) {
    if (original.length != current.length) {
      return false;
    }

    final originalById = <String, AcademicSubtask>{};

    for (final subtask in original) {
      if (originalById.containsKey(subtask.id)) {
        return false;
      }
      originalById[subtask.id] = subtask;
    }

    for (final stored in current) {
      final previous = originalById[stored.id];

      if (previous == null ||
          previous.taskId != stored.taskId ||
          previous.title != stored.title ||
          previous.isCompleted != stored.isCompleted ||
          previous.position != stored.position ||
          previous.createdAt != stored.createdAt ||
          previous.updatedAt != stored.updatedAt) {
        return false;
      }
    }

    return true;
  }

  Future<void> _saveSubtasks(
    Transaction transaction,
    String taskId,
    List<AcademicSubtask> desired,
    DateTime now,
  ) async {
    final rows = await transaction.query(
      'academic_subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    final existing = {
      for (final row in rows)
        (row['id']! as String): AcademicSubtask.fromDatabase(row),
    };

    final retained = <String>{};

    for (var index = 0; index < desired.length; index++) {
      final item = desired[index];
      final isDraft = item.id.startsWith('draft-');

      if (isDraft) {
        final created = AcademicSubtask(
          id: _uuid.v4(),
          taskId: taskId,
          title: item.title.trim(),
          isCompleted: item.isCompleted,
          position: index,
          createdAt: now,
          updatedAt: now,
        );

        await transaction.insert(
          'academic_subtasks',
          created.toDatabase(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        continue;
      }

      final original = existing[item.id];

      if (original == null) {
        throw StateError('La subtarea no pertenece a la tarea actual.');
      }

      retained.add(item.id);

      final updated = AcademicSubtask(
        id: original.id,
        taskId: taskId,
        title: item.title.trim(),
        isCompleted: item.isCompleted,
        position: index,
        createdAt: original.createdAt,
        updatedAt: now,
      );

      final affected = await transaction.update(
        'academic_subtasks',
        updated.toDatabase(),
        where: 'id = ? AND task_id = ?',
        whereArgs: [updated.id, taskId],
      );

      if (affected != 1) {
        throw StateError('No se pudo actualizar una subtarea.');
      }
    }

    for (final original in existing.values) {
      if (!retained.contains(original.id)) {
        final affected = await transaction.delete(
          'academic_subtasks',
          where: 'id = ? AND task_id = ?',
          whereArgs: [original.id, taskId],
        );

        if (affected != 1) {
          throw StateError('No se pudo eliminar una subtarea.');
        }
      }
    }
  }
}
