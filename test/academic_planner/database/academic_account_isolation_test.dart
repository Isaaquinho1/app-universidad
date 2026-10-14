import 'dart:io';

import 'package:conecta_itt/academic_planner/database/academic_database_identity.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'conecta_itt_isolation_',
    );

    await databaseFactoryFfi.setDatabasesPath(temporaryDirectory.path);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('dos cuentas mantienen materias y tareas independientes', () async {
    final accountA = AcademicAccountScope.forUser('student-a');
    final accountB = AcademicAccountScope.forUser('student-b');

    try {
      await accountA.subjects.create(
        name: 'Redes de computadoras',
        colorValue: 0xFF1565C0,
      );

      await accountA.tasks.create(title: 'Práctica de redes');

      await accountB.subjects.create(
        name: 'Inteligencia artificial',
        colorValue: 0xFF6A1B9A,
      );

      await accountB.tasks.create(title: 'Entrenar modelo');

      final subjectsA = await accountA.subjects.getAll();
      final subjectsB = await accountB.subjects.getAll();
      final tasksA = await accountA.tasks.getAll();
      final tasksB = await accountB.tasks.getAll();

      expect(subjectsA.map((item) => item.name), ['Redes de computadoras']);

      expect(subjectsB.map((item) => item.name), ['Inteligencia artificial']);

      expect(tasksA.map((item) => item.title), ['Práctica de redes']);

      expect(tasksB.map((item) => item.title), ['Entrenar modelo']);
    } finally {
      await accountA.close();
      await accountB.close();
    }
  });

  test('cerrar y reabrir una cuenta conserva sus datos', () async {
    final firstSession = AcademicAccountScope.forUser('student-a');

    try {
      await firstSession.subjects.create(
        name: 'Telecomunicaciones',
        colorValue: 0xFF008577,
      );
    } finally {
      await firstSession.close();
    }

    final secondSession = AcademicAccountScope.forUser('student-a');
    final anotherAccount = AcademicAccountScope.forUser('student-b');

    try {
      final originalSubjects = await secondSession.subjects.getAll();
      final otherSubjects = await anotherAccount.subjects.getAll();

      expect(originalSubjects.length, 1);
      expect(originalSubjects.single.name, 'Telecomunicaciones');
      expect(otherSubjects, isEmpty);
    } finally {
      await secondSession.close();
      await anotherAccount.close();
    }
  });

  test('los contextos individuales no crean la base heredada', () async {
    final account = AcademicAccountScope.forUser('student-a');

    try {
      await account.subjects.getAll();

      final legacyPath = path.join(
        temporaryDirectory.path,
        AcademicDatabaseIdentity.legacyDatabaseName,
      );

      expect(await databaseExists(legacyPath), isFalse);
    } finally {
      await account.close();
    }
  });
}
