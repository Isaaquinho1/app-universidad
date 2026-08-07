import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AcademicDatabase {
  AcademicDatabase._();

  static const _databaseName = 'conecta_itt_academic.db';
  static const _databaseVersion = 2;

  static final AcademicDatabase instance = AcademicDatabase._();

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createVersionOne,
      onUpgrade: _upgrade,
    );

    return _database!;
  }

  Future<void> close() async {
    final current = _database;
    if (current == null) return;

    await current.close();
    _database = null;
  }

  static Future<void> _createVersionOne(Database database, int version) async {
    await database.transaction((transaction) async {
      await transaction.execute('''
        CREATE TABLE academic_subjects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          teacher_name TEXT,
          color_value INTEGER NOT NULL,
          notes TEXT,
          is_archived INTEGER NOT NULL DEFAULT 0
            CHECK (is_archived IN (0, 1)),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await transaction.execute('''
        CREATE TABLE class_sessions (
          id TEXT PRIMARY KEY,
          subject_id TEXT NOT NULL,
          weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
          start_minutes INTEGER NOT NULL
            CHECK (start_minutes BETWEEN 0 AND 1439),
          end_minutes INTEGER NOT NULL
            CHECK (end_minutes BETWEEN 1 AND 1440),
          building TEXT,
          room TEXT,
          reminder_minutes INTEGER,
          is_active INTEGER NOT NULL DEFAULT 1
            CHECK (is_active IN (0, 1)),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          CHECK (end_minutes > start_minutes),
          FOREIGN KEY (subject_id)
            REFERENCES academic_subjects(id)
            ON DELETE CASCADE
        )
      ''');

      await transaction.execute('''
        CREATE TABLE task_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color_value INTEGER NOT NULL,
          icon_code_point INTEGER,
          is_system INTEGER NOT NULL DEFAULT 0
            CHECK (is_system IN (0, 1)),
          created_at TEXT NOT NULL
        )
      ''');

      await transaction.execute('''
        CREATE TABLE academic_tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          subject_id TEXT,
          category_id TEXT,
          due_at TEXT,
          priority TEXT NOT NULL DEFAULT 'medium',
          status TEXT NOT NULL DEFAULT 'pending',
          reminder_at TEXT,
          completed_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (subject_id)
            REFERENCES academic_subjects(id)
            ON DELETE SET NULL,
          FOREIGN KEY (category_id)
            REFERENCES task_categories(id)
            ON DELETE SET NULL
        )
      ''');

      await transaction.execute('''
        CREATE INDEX index_class_sessions_subject
        ON class_sessions(subject_id)
      ''');

      await transaction.execute('''
        CREATE INDEX index_class_sessions_weekday_time
        ON class_sessions(weekday, start_minutes)
      ''');

      await transaction.execute('''
        CREATE INDEX index_academic_tasks_due_at
        ON academic_tasks(due_at)
      ''');

      await transaction.execute('''
        CREATE INDEX index_academic_tasks_status
        ON academic_tasks(status)
      ''');

      await _insertDefaultCategories(transaction);
      await _createVersionTwo(transaction);
    });
  }

  static Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.transaction((transaction) async {
        await _createVersionTwo(transaction);
      });
    }
  }

  static Future<void> _createVersionTwo(Transaction transaction) async {
    await transaction.execute('''
      CREATE TABLE academic_subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0
          CHECK (is_completed IN (0, 1)),
        position INTEGER NOT NULL DEFAULT 0
          CHECK (position >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (task_id)
          REFERENCES academic_tasks(id)
          ON DELETE CASCADE
      )
    ''');

    await transaction.execute('''
      CREATE INDEX index_academic_subtasks_task
      ON academic_subtasks(task_id)
    ''');

    await transaction.execute('''
      CREATE INDEX index_academic_subtasks_task_position
      ON academic_subtasks(task_id, position)
    ''');
  }

  static Future<void> _insertDefaultCategories(Transaction transaction) async {
    final createdAt = DateTime.now().toIso8601String();

    const categories = [
      ('system-homework', 'Tarea', 0xFF1565C0),
      ('system-project', 'Proyecto', 0xFF6A1B9A),
      ('system-exam', 'Examen', 0xFFC62828),
      ('system-presentation', 'Exposición', 0xFFEF6C00),
      ('system-practice', 'Práctica', 0xFF2E7D32),
      ('system-reading', 'Lectura', 0xFF455A64),
    ];

    for (final category in categories) {
      await transaction.insert('task_categories', {
        'id': category.$1,
        'name': category.$2,
        'color_value': category.$3,
        'icon_code_point': null,
        'is_system': 1,
        'created_at': createdAt,
      });
    }
  }
}
