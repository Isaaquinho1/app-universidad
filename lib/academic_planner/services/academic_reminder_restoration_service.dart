import 'package:conecta_itt/academic_planner/repositories/repositories.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_reminder_service.dart';
import 'package:conecta_itt/academic_planner/services/class_session_reminder_service.dart';
import 'package:logger/logger.dart';

/// Reconcilia los recordatorios académicos persistidos en SQLite con las
/// notificaciones locales programadas por el sistema operativo.
///
/// La restauración es idempotente: los servicios de tareas y clases cancelan
/// primero el ID determinista correspondiente y después vuelven a programarlo
/// únicamente cuando el modelo sigue requiriendo un recordatorio.
class AcademicReminderRestorationService {
  AcademicReminderRestorationService({
    AcademicTaskRepository? taskRepository,
    AcademicSubjectRepository? subjectRepository,
    ClassSessionRepository? classSessionRepository,
    AcademicTaskReminderService? taskReminderService,
    ClassSessionReminderService? classSessionReminderService,
  }) : _taskRepository = taskRepository ?? AcademicTaskRepository(),
       _subjectRepository = subjectRepository ?? AcademicSubjectRepository(),
       _classSessionRepository =
           classSessionRepository ?? ClassSessionRepository(),
       _taskReminderService =
           taskReminderService ?? AcademicTaskReminderService(),
       _classSessionReminderService =
           classSessionReminderService ?? ClassSessionReminderService();

  final AcademicTaskRepository _taskRepository;
  final AcademicSubjectRepository _subjectRepository;
  final ClassSessionRepository _classSessionRepository;
  final AcademicTaskReminderService _taskReminderService;
  final ClassSessionReminderService _classSessionReminderService;

  Future<void> restore() async {
    try {
      final results = await Future.wait<Object>([
        _taskRepository.getAll(),
        _subjectRepository.getAll(),
        _classSessionRepository.getAll(),
      ]);

      final tasks = results[0] as List;
      final subjects = results[1] as List;
      final sessions = results[2] as List;

      final subjectsById = {
        for (final subject in subjects) subject.id as String: subject,
      };

      await _taskReminderService.restore(tasks.cast());

      await _classSessionReminderService.restore(
        sessions: sessions.cast(),
        subjectsById: subjectsById.cast(),
      );

      Logger().i(
        'Academic reminders restored: '
        'tasks=${tasks.length}, '
        'subjects=${subjects.length}, '
        'sessions=${sessions.length}.',
      );
    } catch (error, stackTrace) {
      Logger().w(
        'Academic reminders could not be restored.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
