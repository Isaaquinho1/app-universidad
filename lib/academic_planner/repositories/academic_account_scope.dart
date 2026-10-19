import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subtask_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/class_session_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/daily_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/task_category_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/weekly_schedule_repository.dart';

/// Agrupa el almacenamiento académico de una cuenta autenticada.
///
/// No abre la base al construirse y nunca utiliza la base heredada.
/// La aplicación debe cerrar este contexto al terminar la sesión,
/// después de detener las operaciones académicas pendientes.
class AcademicAccountScope {
  AcademicAccountScope.forUser(String userId)
    : userId = userId.trim(),
      database = AcademicDatabase.forUser(userId);

  final String userId;
  final AcademicDatabase database;

  late final AcademicSubjectRepository subjects = AcademicSubjectRepository(
    academicDatabase: database,
  );

  late final AcademicTaskRepository tasks = AcademicTaskRepository(
    academicDatabase: database,
  );

  late final AcademicSubtaskRepository subtasks = AcademicSubtaskRepository(
    academicDatabase: database,
  );

  late final TaskCategoryRepository categories = TaskCategoryRepository(
    academicDatabase: database,
  );

  late final ClassSessionRepository sessions = ClassSessionRepository(
    academicDatabase: database,
  );

  late final DailyScheduleRepository dailySchedule = DailyScheduleRepository(
    academicDatabase: database,
  );

  late final WeeklyScheduleRepository weeklySchedule = WeeklyScheduleRepository(
    academicDatabase: database,
  );

  bool _closing = false;
  bool _invalidated = false;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;
  Future<void>? _closeFuture;

  /// Invalida permanentemente las operaciones de esta sesión.
  ///
  /// No elimina datos ni cierra una transacción activa por la fuerza.
  void invalidate() {
    _invalidated = true;
  }

  void _ensureCanStart() {
    if (_closing || _invalidated) {
      throw StateError('El contexto académico no acepta nuevas operaciones.');
    }
  }

  void _ensureSessionValid() {
    if (_invalidated) {
      throw StateError('La sesión académica fue invalidada.');
    }
  }

  /// Registra una operación para impedir que SQLite se cierre
  /// mientras la operación continúa en ejecución.
  Future<T> run<T>(Future<T> Function() operation) async {
    _ensureCanStart();

    _activeOperations++;

    try {
      return await operation();
    } finally {
      _activeOperations--;

      if (_activeOperations == 0) {
        final completer = _idleCompleter;
        _idleCompleter = null;
        completer?.complete();
      }
    }
  }

  /// Ejecuta una transacción SQLite vinculada a esta cuenta.
  ///
  /// La conexión permanece abierta hasta confirmar o revertir
  /// la transacción. El callback debe utilizar exclusivamente
  /// el objeto Transaction recibido.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) operation,
  ) {
    return run(() async {
      final connection = await database.database;
      _ensureSessionValid();

      return connection.transaction<T>((transaction) async {
        _ensureSessionValid();
        final result = await operation(transaction);
        _ensureSessionValid();
        return result;
      });
    });
  }

  /// Rechaza operaciones nuevas y espera las operaciones registradas
  /// antes de cerrar la conexión SQLite.
  Future<void> close() => _closeFuture ??= _closeWhenIdle();

  Future<void> _closeWhenIdle() async {
    _closing = true;

    if (_activeOperations > 0) {
      _idleCompleter ??= Completer<void>();
      await _idleCompleter!.future;
    }

    await database.close();
  }
}
