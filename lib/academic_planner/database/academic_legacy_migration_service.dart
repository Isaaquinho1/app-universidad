import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/database/academic_database_identity.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Copia datos académicos heredados a una base individual.
///
/// Debe invocarse únicamente después de que el usuario autenticado
/// confirme que los datos heredados le pertenecen.
///
/// No elimina ni modifica la base de origen.
class AcademicLegacyMigrationService {
  const AcademicLegacyMigrationService();

  static const _tables = [
    'academic_subjects',
    'task_categories',
    'class_sessions',
    'academic_tasks',
    'academic_subtasks',
  ];

  Future<bool> legacyDatabaseExists() async {
    final directory = await getDatabasesPath();
    final sourcePath = path.join(
      directory,
      AcademicDatabaseIdentity.legacyDatabaseName,
    );

    return databaseExists(sourcePath);
  }

  Future<Map<String, int>> inspectLegacyData() async {
    final snapshot = await _readLegacySnapshot();

    return {
      for (final entry in snapshot.entries) entry.key: entry.value.length,
    };
  }

  Future<void> migrateForUser(String userId) async {
    // Valida el identificador antes de acceder al almacenamiento.
    AcademicDatabaseIdentity.databaseNameForUser(userId);

    final snapshot = await _readLegacySnapshot();
    final target = AcademicDatabase.forUser(userId);

    try {
      final database = await target.database;

      await database.transaction((transaction) async {
        // Nunca sobrescribir datos académicos ya existentes.
        for (final table in _tables) {
          final rows = await transaction.query(
            table,
            where: table == 'task_categories' ? 'is_system = ?' : null,
            whereArgs: table == 'task_categories' ? const [0] : null,
            limit: 1,
          );

          if (rows.isNotEmpty) {
            throw StateError(
              'La base individual ya contiene datos. '
              'No se realizará la migración.',
            );
          }
        }

        for (final table in _tables) {
          for (final row in snapshot[table]!) {
            final isSystemCategory =
                table == 'task_categories' && row['is_system'] == 1;

            await transaction.insert(
              table,
              row,
              conflictAlgorithm:
                  isSystemCategory
                      ? ConflictAlgorithm.ignore
                      : ConflictAlgorithm.abort,
            );
          }
        }

        // Verifica la presencia de todos los registros copiados.
        for (final table in _tables) {
          for (final sourceRow in snapshot[table]!) {
            final rows = await transaction.query(
              table,
              where: 'id = ?',
              whereArgs: [sourceRow['id']],
              limit: 1,
            );

            if (rows.length != 1) {
              throw StateError('La migración no pudo verificar $table.');
            }

            // Las categorías predeterminadas se crean al abrir
            // una base nueva y pueden tener fechas diferentes.
            final isSystemCategory =
                table == 'task_categories' && sourceRow['is_system'] == 1;

            if (isSystemCategory) {
              continue;
            }

            final targetRow = rows.single;

            final matches = sourceRow.entries.every(
              (entry) => targetRow[entry.key] == entry.value,
            );

            if (!matches) {
              throw StateError('Los datos migrados no coinciden en $table.');
            }
          }
        }
      });
    } finally {
      await target.close();
    }
  }

  Future<Map<String, List<Map<String, Object?>>>> _readLegacySnapshot() async {
    final directory = await getDatabasesPath();
    final sourcePath = path.join(
      directory,
      AcademicDatabaseIdentity.legacyDatabaseName,
    );

    if (!await databaseExists(sourcePath)) {
      throw StateError('No existe una base académica heredada para migrar.');
    }

    final source = await openDatabase(
      sourcePath,
      readOnly: true,
      singleInstance: false,
    );

    try {
      return await source.transaction((transaction) async {
        final snapshot = <String, List<Map<String, Object?>>>{};

        for (final table in _tables) {
          snapshot[table] = await transaction.query(table);
        }

        return snapshot;
      });
    } finally {
      await source.close();
    }
  }
}
