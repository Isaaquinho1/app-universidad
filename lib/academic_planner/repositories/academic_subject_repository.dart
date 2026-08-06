import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AcademicSubjectRepository {
  AcademicSubjectRepository({AcademicDatabase? academicDatabase, Uuid? uuid})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AcademicDatabase _academicDatabase;
  final Uuid _uuid;

  Future<AcademicSubject> create({
    required String name,
    required int colorValue,
    String? code,
    String? teacherName,
    String? notes,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'La materia requiere un nombre.');
    }

    final now = DateTime.now();

    final subject = AcademicSubject(
      id: _uuid.v4(),
      name: normalizedName,
      code: _normalizeOptional(code),
      teacherName: _normalizeOptional(teacherName),
      colorValue: colorValue,
      notes: _normalizeOptional(notes),
      createdAt: now,
      updatedAt: now,
    );

    final database = await _academicDatabase.database;
    await database.insert(
      'academic_subjects',
      subject.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return subject;
  }

  Future<List<AcademicSubject>> getAll({bool includeArchived = false}) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'academic_subjects',
      where: includeArchived ? null : 'is_archived = ?',
      whereArgs: includeArchived ? null : const [0],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(AcademicSubject.fromDatabase).toList(growable: false);
  }

  Future<AcademicSubject?> getById(String id) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'academic_subjects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return AcademicSubject.fromDatabase(rows.first);
  }

  Future<AcademicSubject> update(AcademicSubject subject) async {
    final normalizedName = subject.name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        subject.name,
        'name',
        'La materia requiere un nombre.',
      );
    }

    final updated = subject.copyWith(
      name: normalizedName,
      updatedAt: DateTime.now(),
    );

    final database = await _academicDatabase.database;
    final affectedRows = await database.update(
      'academic_subjects',
      updated.toDatabase(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la materia que se quería actualizar.');
    }

    return updated;
  }

  Future<void> setArchived({required String id, required bool archived}) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.update(
      'academic_subjects',
      {
        'is_archived': archived ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la materia indicada.');
    }
  }

  Future<void> delete(String id) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.delete(
      'academic_subjects',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la materia indicada.');
    }
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
