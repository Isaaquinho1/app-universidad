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

  Future<void> close() => database.close();
}
