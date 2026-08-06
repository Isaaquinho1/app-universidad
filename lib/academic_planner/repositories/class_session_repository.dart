import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ClassSessionRepository {
  ClassSessionRepository({AcademicDatabase? academicDatabase, Uuid? uuid})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AcademicDatabase _academicDatabase;
  final Uuid _uuid;

  Future<ClassSession> create({
    required String subjectId,
    required int weekday,
    required int startMinutes,
    required int endMinutes,
    String? building,
    String? room,
    int? reminderMinutes,
  }) async {
    _validateSchedule(
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      reminderMinutes: reminderMinutes,
    );

    if (await hasConflict(
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    )) {
      throw const ClassScheduleConflictException();
    }

    final now = DateTime.now();

    final session = ClassSession(
      id: _uuid.v4(),
      subjectId: subjectId,
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      building: _normalizeOptional(building),
      room: _normalizeOptional(room),
      reminderMinutes: reminderMinutes,
      createdAt: now,
      updatedAt: now,
    );

    final database = await _academicDatabase.database;
    await database.insert(
      'class_sessions',
      session.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return session;
  }

  Future<List<ClassSession>> getAll({bool onlyActive = true}) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'class_sessions',
      where: onlyActive ? 'is_active = ?' : null,
      whereArgs: onlyActive ? const [1] : null,
      orderBy: 'weekday ASC, start_minutes ASC',
    );

    return rows.map(ClassSession.fromDatabase).toList(growable: false);
  }

  Future<List<ClassSession>> getByWeekday(
    int weekday, {
    bool onlyActive = true,
  }) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday');
    }

    final database = await _academicDatabase.database;

    final where = onlyActive ? 'weekday = ? AND is_active = ?' : 'weekday = ?';

    final whereArgs = onlyActive ? [weekday, 1] : [weekday];

    final rows = await database.query(
      'class_sessions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_minutes ASC',
    );

    return rows.map(ClassSession.fromDatabase).toList(growable: false);
  }

  Future<List<ClassSession>> getBySubject(String subjectId) async {
    final database = await _academicDatabase.database;

    final rows = await database.query(
      'class_sessions',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'weekday ASC, start_minutes ASC',
    );

    return rows.map(ClassSession.fromDatabase).toList(growable: false);
  }

  Future<bool> hasConflict({
    required int weekday,
    required int startMinutes,
    required int endMinutes,
    String? excludingSessionId,
  }) async {
    final database = await _academicDatabase.database;

    final clauses = <String>[
      'weekday = ?',
      'is_active = 1',
      'start_minutes < ?',
      'end_minutes > ?',
    ];

    final arguments = <Object?>[weekday, endMinutes, startMinutes];

    if (excludingSessionId != null) {
      clauses.add('id != ?');
      arguments.add(excludingSessionId);
    }

    final rows = await database.query(
      'class_sessions',
      columns: const ['id'],
      where: clauses.join(' AND '),
      whereArgs: arguments,
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<ClassSession> update(ClassSession session) async {
    _validateSchedule(
      weekday: session.weekday,
      startMinutes: session.startMinutes,
      endMinutes: session.endMinutes,
      reminderMinutes: session.reminderMinutes,
    );

    if (await hasConflict(
      weekday: session.weekday,
      startMinutes: session.startMinutes,
      endMinutes: session.endMinutes,
      excludingSessionId: session.id,
    )) {
      throw const ClassScheduleConflictException();
    }

    final updated = ClassSession(
      id: session.id,
      subjectId: session.subjectId,
      weekday: session.weekday,
      startMinutes: session.startMinutes,
      endMinutes: session.endMinutes,
      building: _normalizeOptional(session.building),
      room: _normalizeOptional(session.room),
      reminderMinutes: session.reminderMinutes,
      isActive: session.isActive,
      createdAt: session.createdAt,
      updatedAt: DateTime.now(),
    );

    final database = await _academicDatabase.database;
    final affectedRows = await database.update(
      'class_sessions',
      updated.toDatabase(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la sesión de clase indicada.');
    }

    return updated;
  }

  Future<void> delete(String id) async {
    final database = await _academicDatabase.database;

    final affectedRows = await database.delete(
      'class_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (affectedRows != 1) {
      throw StateError('No se encontró la sesión de clase indicada.');
    }
  }

  void _validateSchedule({
    required int weekday,
    required int startMinutes,
    required int endMinutes,
    int? reminderMinutes,
  }) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday');
    }

    if (startMinutes < 0 || startMinutes >= 1440) {
      throw ArgumentError.value(startMinutes, 'startMinutes');
    }

    if (endMinutes <= startMinutes || endMinutes > 1440) {
      throw ArgumentError.value(endMinutes, 'endMinutes');
    }

    if (reminderMinutes != null && reminderMinutes < 0) {
      throw ArgumentError.value(reminderMinutes, 'reminderMinutes');
    }
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class ClassScheduleConflictException implements Exception {
  const ClassScheduleConflictException();

  @override
  String toString() {
    return 'La clase se traslapa con otra sesión registrada.';
  }
}
