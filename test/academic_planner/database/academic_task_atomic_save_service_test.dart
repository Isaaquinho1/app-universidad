import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_atomic_save_service.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_form_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AcademicAccountScope account;
  late AcademicTaskAtomicSaveService service;

  setUp(() {
    account = AcademicAccountScope.forUser(
      'test-atomic-save-${DateTime.now().microsecondsSinceEpoch}',
    );
    service = AcademicTaskAtomicSaveService(account: account);
  });

  tearDown(() async {
    await account.close();
  });

  AcademicSubtask draft(String id, String title) {
    final now = DateTime.now();

    return AcademicSubtask(
      id: 'draft-$id',
      taskId: '',
      title: title,
      isCompleted: false,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  AcademicTaskFormData form({
    required String title,
    List<AcademicSubtask> subtasks = const [],
  }) {
    return AcademicTaskFormData(
      title: title,
      priority: TaskPriority.medium,
      status: AcademicTaskStatus.pending,
      subtasks: subtasks,
    );
  }

  test('crea una tarea y sus subtareas en una operación', () async {
    final created = await service.save(
      form: form(
        title: 'Proyecto final',
        subtasks: [
          draft('a', 'Investigar'),
          draft('b', 'Preparar presentación'),
        ],
      ),
    );

    final tasks = await account.tasks.getAll();
    final subtasks = await account.subtasks.getForTask(created.id);

    expect(tasks.any((task) => task.id == created.id), isTrue);
    expect(subtasks, hasLength(2));
    expect(subtasks.map((subtask) => subtask.title).toList(), [
      'Investigar',
      'Preparar presentación',
    ]);
    expect(subtasks.map((subtask) => subtask.position).toList(), [0, 1]);
    expect(
      subtasks.every((subtask) => !subtask.id.startsWith('draft-')),
      isTrue,
    );
  });

  test(
    'actualiza tarea y reconcilia subtareas sin perder identidades',
    () async {
      final original = await service.save(
        form: form(
          title: 'Proyecto original',
          subtasks: [
            draft('uno', 'Primera'),
            draft('dos', 'Segunda'),
            draft('tres', 'Tercera'),
          ],
        ),
      );

      final previous = await account.subtasks.getForTask(original.id);

      expect(previous, hasLength(3));

      final first = previous[0];
      final second = previous[1];
      final third = previous[2];

      final editedThird = third.copyWith(
        title: 'Tercera modificada',
        isCompleted: true,
      );

      final updated = await service.save(
        previousTask: original,
        originalSubtasks: previous,
        form: form(
          title: 'Proyecto actualizado',
          subtasks: [editedThird, first, draft('cuatro', 'Cuarta')],
        ),
      );

      final persisted = await account.subtasks.getForTask(updated.id);

      expect(updated.id, original.id);
      expect(updated.title, 'Proyecto actualizado');
      expect(persisted, hasLength(3));

      expect(persisted.map((item) => item.title).toList(), [
        'Tercera modificada',
        'Primera',
        'Cuarta',
      ]);

      expect(persisted.map((item) => item.position).toList(), [0, 1, 2]);

      expect(persisted[0].id, third.id);
      expect(persisted[0].createdAt, third.createdAt);
      expect(persisted[0].isCompleted, isTrue);

      expect(persisted[1].id, first.id);
      expect(persisted[1].createdAt, first.createdAt);

      expect(persisted.any((item) => item.id == second.id), isFalse);

      final savedTasks = await account.tasks.getAll();
      final savedTask = savedTasks.singleWhere(
        (task) => task.id == original.id,
      );

      expect(savedTask.title, 'Proyecto actualizado');
    },
  );

  test('rechaza una edición obsoleta sin sobrescribir cambios', () async {
    final originalTask = await service.save(
      form: form(
        title: 'Versión original',
        subtasks: [draft('original', 'Subtarea original')],
      ),
    );

    final originalSubtasks = await account.subtasks.getForTask(originalTask.id);

    final firstEdit = await service.save(
      previousTask: originalTask,
      originalSubtasks: originalSubtasks,
      form: form(
        title: 'Versión actualizada',
        subtasks: [draft('nueva', 'Subtarea actualizada')],
      ),
    );

    expect(firstEdit.id, originalTask.id);

    await expectLater(
      () async => service.save(
        previousTask: originalTask,
        originalSubtasks: originalSubtasks,
        form: form(
          title: 'Edición obsoleta',
          subtasks: [draft('obsoleta', 'No debe guardarse')],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final savedTasks = await account.tasks.getAll();
    final savedTask = savedTasks.singleWhere(
      (task) => task.id == originalTask.id,
    );

    final savedSubtasks = await account.subtasks.getForTask(originalTask.id);

    expect(savedTask.title, 'Versión actualizada');
    expect(savedSubtasks, hasLength(1));
    expect(savedSubtasks.single.title, 'Subtarea actualizada');
    expect(
      savedSubtasks.any((item) => item.title == 'No debe guardarse'),
      isFalse,
    );
  });

  test('mantiene updated_at monotónico ante una fecha futura', () async {
    final originalTask = await service.save(
      form: form(title: 'Tarea con versión futura'),
    );

    final futureVersion = DateTime.now().add(const Duration(days: 1));

    final connection = await account.database.database;

    await connection.update(
      'academic_tasks',
      {'updated_at': futureVersion.toIso8601String()},
      where: 'id = ?',
      whereArgs: [originalTask.id],
    );

    final storedTasks = await account.tasks.getAll();

    final futureTask = storedTasks.singleWhere(
      (task) => task.id == originalTask.id,
    );

    final updated = await service.save(
      previousTask: futureTask,
      originalSubtasks: const [],
      form: form(title: 'Versión monotónica'),
    );

    expect(updated.updatedAt.isAfter(futureVersion), isTrue);

    final persistedTasks = await account.tasks.getAll();

    final persisted = persistedTasks.singleWhere(
      (task) => task.id == originalTask.id,
    );

    expect(persisted.title, 'Versión monotónica');
    expect(persisted.updatedAt, updated.updatedAt);
  });

  test('rechaza cambios externos en subtareas sin sobrescribirlos', () async {
    final task = await service.save(
      form: form(
        title: 'Proyecto original',
        subtasks: [draft('paso-1', 'Preparar investigación')],
      ),
    );

    final originalSubtasks = await account.subtasks.getForTask(task.id);

    expect(originalSubtasks, hasLength(1));

    final subtask = originalSubtasks.single;
    final connection = await account.database.database;

    final affected = await connection.update(
      'academic_subtasks',
      {'title': 'Investigación revisada externamente', 'is_completed': 1},
      where: 'id = ? AND task_id = ?',
      whereArgs: [subtask.id, task.id],
    );

    expect(affected, 1);

    await expectLater(
      () async => service.save(
        previousTask: task,
        originalSubtasks: originalSubtasks,
        form: form(
          title: 'Proyecto desde formulario antiguo',
          subtasks: [subtask],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'mensaje',
          contains('subtareas fueron modificadas'),
        ),
      ),
    );

    final persistedTasks = await account.tasks.getAll();
    final persistedTask = persistedTasks.singleWhere(
      (item) => item.id == task.id,
    );

    final persistedSubtasks = await account.subtasks.getForTask(task.id);

    expect(persistedTask.title, 'Proyecto original');
    expect(persistedSubtasks, hasLength(1));
    expect(
      persistedSubtasks.single.title,
      'Investigación revisada externamente',
    );
    expect(persistedSubtasks.single.isCompleted, isTrue);
  });

  test('rechaza una edición sin subtareas originales', () async {
    final task = await service.save(
      form: form(
        title: 'Tarea protegida',
        subtasks: [draft('inicial', 'Subtarea protegida')],
      ),
    );

    await expectLater(
      () async => service.save(
        previousTask: task,
        form: form(title: 'Edición sin referencia', subtasks: []),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'mensaje',
          contains('requiere las subtareas originales'),
        ),
      ),
    );

    final savedTasks = await account.tasks.getAll();
    final savedTask = savedTasks.singleWhere((item) => item.id == task.id);

    final savedSubtasks = await account.subtasks.getForTask(task.id);

    expect(savedTask.title, 'Tarea protegida');
    expect(savedSubtasks, hasLength(1));
    expect(savedSubtasks.single.title, 'Subtarea protegida');
  });

  test('revierte una tarea insertada si falla una subtarea', () async {
    final before = await account.tasks.getAll();

    final now = DateTime.now();
    final invalidSubtask = AcademicSubtask(
      id: 'subtask-inexistente',
      taskId: '',
      title: 'Subtarea sin registro previo',
      isCompleted: false,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );

    await expectLater(
      () async => service.save(
        form: form(
          title: 'Tarea que debe revertirse',
          subtasks: [invalidSubtask],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final after = await account.tasks.getAll();

    expect(after.length, before.length);
    expect(
      after.any((task) => task.title == 'Tarea que debe revertirse'),
      isFalse,
    );
  });

  test('revierte la tarea si falla la inserción de una subtarea', () async {
    final invalid = draft('invalid', 'Subtarea inválida');

    final corrupted = AcademicSubtask(
      id: invalid.id,
      taskId: invalid.taskId,
      title: invalid.title,
      isCompleted: invalid.isCompleted,
      position: invalid.position,
      createdAt: invalid.createdAt,
      updatedAt: invalid.updatedAt,
    );

    final existing = await account.tasks.getAll();
    final initialCount = existing.length;

    await expectLater(
      () async => service.save(
        form: form(
          title: 'No debe persistirse',
          subtasks: [corrupted, corrupted],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final after = await account.tasks.getAll();

    expect(after.length, initialCount);
    expect(after.any((task) => task.title == 'No debe persistirse'), isFalse);
  });
}
