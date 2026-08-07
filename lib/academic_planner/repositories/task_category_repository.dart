import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class TaskCategoryRepository {
  TaskCategoryRepository({AcademicDatabase? academicDatabase, Uuid? uuid})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AcademicDatabase _academicDatabase;
  final Uuid _uuid;

  Future<TaskCategory> create({
    required String name,
    required int colorValue,
    int? iconCodePoint,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name');
    }

    final category = TaskCategory(
      id: _uuid.v4(),
      name: normalizedName,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      createdAt: DateTime.now(),
    );

    final database = await _academicDatabase.database;
    await database.insert(
      'task_categories',
      category.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return category;
  }

  Future<TaskCategory> update({
    required TaskCategory category,
    required String name,
    required int colorValue,
    int? iconCodePoint,
  }) async {
    if (category.isSystem) {
      throw StateError('Las categorías predeterminadas no pueden modificarse.');
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'La categoría requiere un nombre.',
      );
    }

    final updated = TaskCategory(
      id: category.id,
      name: normalizedName,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      isSystem: false,
      createdAt: category.createdAt,
    );

    final database = await _academicDatabase.database;

    final affectedRows = await database.update(
      'task_categories',
      updated.toDatabase(),
      where: 'id = ?',
      whereArgs: [updated.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la categoría indicada.');
    }

    return updated;
  }

  Future<List<TaskCategory>> getAll() async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'task_categories',
      orderBy: 'is_system DESC, name COLLATE NOCASE ASC',
    );

    return rows.map(TaskCategory.fromDatabase).toList(growable: false);
  }

  Future<void> delete(String id) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'task_categories',
      columns: const ['is_system'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('No se encontró la categoría indicada.');
    }

    if ((rows.first['is_system']! as int) == 1) {
      throw StateError('Las categorías predeterminadas no pueden eliminarse.');
    }

    await database.delete('task_categories', where: 'id = ?', whereArgs: [id]);
  }
}
