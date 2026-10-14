import 'dart:io';

import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/database/academic_legacy_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;

  const service = AcademicLegacyMigrationService();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'conecta_itt_migration_',
    );

    await databaseFactoryFfi.setDatabasesPath(temporaryDirectory.path);
  });

  tearDown(() async {
    await AcademicDatabase.instance.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<void> createSampleAcademicData() async {
    final database = await AcademicDatabase.instance.database;

    const date = '2026-10-13T12:00:00.000';

    await database.insert('academic_subjects', {
      'id': 'subject-1',
      'name': 'Redes de computadoras',
      'color_value': 0xFF1565C0,
      'created_at': date,
      'updated_at': date,
    });

    await database.insert('class_sessions', {
      'id': 'session-1',
      'subject_id': 'subject-1',
      'weekday': 1,
      'start_minutes': 480,
      'end_minutes': 540,
      'created_at': date,
      'updated_at': date,
    });

    await database.insert('academic_tasks', {
      'id': 'task-1',
      'title': 'Práctica de redes',
      'subject_id': 'subject-1',
      'category_id': 'system-homework',
      'created_at': date,
      'updated_at': date,
    });

    await database.insert('academic_subtasks', {
      'id': 'subtask-1',
      'task_id': 'task-1',
      'title': 'Preparar topología',
      'created_at': date,
      'updated_at': date,
    });
  }

  test('inspecciona los registros originales', () async {
    await createSampleAcademicData();

    final counts = await service.inspectLegacyData();

    expect(counts['academic_subjects'], 1);
    expect(counts['class_sessions'], 1);
    expect(counts['academic_tasks'], 1);
    expect(counts['academic_subtasks'], 1);
    expect(counts['task_categories'], greaterThanOrEqualTo(6));
  });

  test('migra todas las relaciones y conserva el origen', () async {
    await createSampleAcademicData();

    final before = await service.inspectLegacyData();

    await service.migrateForUser('student-test-1');

    final target = AcademicDatabase.forUser('student-test-1');

    try {
      final database = await target.database;

      for (final entry in before.entries) {
        final rows = await database.query(entry.key);
        expect(
          rows.length,
          entry.value,
          reason: 'Cantidad incorrecta en ${entry.key}',
        );
      }

      final tasks = await database.query('academic_tasks');

      expect(tasks.single['title'], 'Práctica de redes');
      expect(tasks.single['subject_id'], 'subject-1');

      final subtasks = await database.query('academic_subtasks');

      expect(subtasks.single['task_id'], 'task-1');
    } finally {
      await target.close();
    }

    final after = await service.inspectLegacyData();

    expect(after, before);
  });

  test('no sobrescribe datos de otra cuenta', () async {
    await createSampleAcademicData();

    final target = AcademicDatabase.forUser('student-test-2');
    final database = await target.database;

    await database.insert('academic_subjects', {
      'id': 'existing-subject',
      'name': 'Materia existente',
      'color_value': 0xFF123456,
      'created_at': '2026-10-13T12:00:00.000',
      'updated_at': '2026-10-13T12:00:00.000',
    });

    await target.close();

    await expectLater(
      service.migrateForUser('student-test-2'),
      throwsStateError,
    );

    final reopened = AcademicDatabase.forUser('student-test-2');

    try {
      final rows = await (await reopened.database).query('academic_subjects');

      expect(rows.length, 1);
      expect(rows.single['id'], 'existing-subject');
    } finally {
      await reopened.close();
    }
  });

  test('rechaza una migración si no existe el origen', () async {
    expect(await service.legacyDatabaseExists(), isFalse);

    await expectLater(
      service.migrateForUser('student-test-3'),
      throwsStateError,
    );
  });

  test('rechaza una segunda migración sobre la misma cuenta', () async {
    await createSampleAcademicData();

    await service.migrateForUser('student-test-4');

    await expectLater(
      service.migrateForUser('student-test-4'),
      throwsStateError,
    );
  });
}
