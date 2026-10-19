import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('reemplazar un contexto del mismo UID conserva sus datos', () async {
    const uid = 'test-account-replacement';

    final previous = AcademicAccountScope.forUser(uid);
    final next = AcademicAccountScope.forUser(uid);

    try {
      final previousDb = await previous.database.database;

      await previousDb.delete(
        'task_categories',
        where: 'id = ?',
        whereArgs: ['replacement-test-category'],
      );

      await previous.runTransaction((transaction) async {
        await transaction.insert('task_categories', {
          'id': 'replacement-test-category',
          'name': 'Categoría de reemplazo',
          'color_value': 4280391411,
          'is_system': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      previous.invalidate();
      final closing = previous.close();

      final nextDb = await next.database.database;

      final rows = await nextDb.query(
        'task_categories',
        where: 'id = ?',
        whereArgs: ['replacement-test-category'],
      );

      expect(rows, hasLength(1));
      expect(rows.single['name'], 'Categoría de reemplazo');

      await closing;

      final rowsAfterClose = await nextDb.query(
        'task_categories',
        where: 'id = ?',
        whereArgs: ['replacement-test-category'],
      );

      expect(rowsAfterClose, hasLength(1));
    } finally {
      await previous.close();
      await next.close();
    }
  });
}
