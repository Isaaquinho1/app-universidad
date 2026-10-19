import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AcademicAccountScope account;

  setUp(() {
    account = AcademicAccountScope.forUser(
      'test-transaction-${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await account.close();
  });

  test('confirma todas las escrituras exitosas', () async {
    await account.runTransaction((transaction) async {
      await transaction.insert('task_categories', {
        'id': 'tx-category-a',
        'name': 'Categoría A',
        'color_value': 1,
        'is_system': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      await transaction.insert('task_categories', {
        'id': 'tx-category-b',
        'name': 'Categoría B',
        'color_value': 2,
        'is_system': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    final connection = await account.database.database;
    final rows = await connection.query(
      'task_categories',
      where: 'id IN (?, ?)',
      whereArgs: ['tx-category-a', 'tx-category-b'],
    );

    expect(rows, hasLength(2));
  });

  test('revierte todas las escrituras si ocurre un error', () async {
    await expectLater(
      account.runTransaction<void>((transaction) async {
        await transaction.insert('task_categories', {
          'id': 'tx-rollback-a',
          'name': 'Categoría para revertir',
          'color_value': 3,
          'is_system': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        throw StateError('Fallo intencional');
      }),
      throwsStateError,
    );

    final connection = await account.database.database;
    final rows = await connection.query(
      'task_categories',
      where: 'id = ?',
      whereArgs: ['tx-rollback-a'],
    );

    expect(rows, isEmpty);
  });

  test('close espera una transacción activa', () async {
    final started = Completer<void>();
    final finish = Completer<void>();

    final operation = account.runTransaction<void>((transaction) async {
      started.complete();
      await finish.future;
    });

    await started.future;

    var closed = false;
    final closing = account.close().then((_) {
      closed = true;
    });

    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);

    finish.complete();

    await operation;
    await closing;

    expect(closed, isTrue);
  });

  test('rechaza operaciones después de invalidar la sesión', () async {
    account.invalidate();

    var executed = false;

    await expectLater(
      account.run<void>(() async {
        executed = true;
      }),
      throwsStateError,
    );

    expect(executed, isFalse);
  });

  test('rechaza transacciones después de invalidar la sesión', () async {
    account.invalidate();

    var executed = false;

    await expectLater(
      account.runTransaction<void>((transaction) async {
        executed = true;
      }),
      throwsStateError,
    );

    expect(executed, isFalse);
  });

  test('revierte escrituras al invalidar una transacción activa', () async {
    final inserted = Completer<void>();
    final resume = Completer<void>();

    final operation = account.runTransaction<void>((transaction) async {
      await transaction.insert('task_categories', {
        'id': 'tx-invalidated',
        'name': 'Categoría temporal',
        'color_value': 4,
        'is_system': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      inserted.complete();
      await resume.future;
    });

    await inserted.future;

    account.invalidate();
    resume.complete();

    await expectLater(operation, throwsStateError);

    final connection = await account.database.database;
    final rows = await connection.query(
      'task_categories',
      where: 'id = ?',
      whereArgs: ['tx-invalidated'],
    );

    expect(rows, isEmpty);
  });

  test('rechaza transacciones después del cierre', () async {
    await account.close();

    await expectLater(
      account.runTransaction<void>((transaction) async {}),
      throwsStateError,
    );
  });
}
