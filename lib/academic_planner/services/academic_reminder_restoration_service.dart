import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/repositories/repositories.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
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
    required String userId,
    AcademicAccountScope? account,
    required this.coordinator,
    required this.authRevision,
    required AcademicTaskRepository taskRepository,
    required AcademicSubjectRepository subjectRepository,
    required ClassSessionRepository classSessionRepository,
    AcademicTaskReminderService? taskReminderService,
    ClassSessionReminderService? classSessionReminderService,
  }) : _userId = userId,
       _account = account,
       _taskRepository = taskRepository,
       _subjectRepository = subjectRepository,
       _classSessionRepository = classSessionRepository,
       _taskReminderService =
           taskReminderService ??
           AcademicTaskReminderService(
             userId: userId,
             coordinator: coordinator,
             authRevision: authRevision,
           ),
       _classSessionReminderService =
           classSessionReminderService ??
           ClassSessionReminderService(
             userId: userId,
             coordinator: coordinator,
             authRevision: authRevision,
           );

  /// Utiliza exclusivamente los repositorios de la cuenta indicada.
  ///
  /// No ejecuta la restauración al construir el servicio.
  factory AcademicReminderRestorationService.forAccount(
    AcademicAccountScope account, {
    required AcademicReminderOperationCoordinator coordinator,
    required int authRevision,
  }) {
    return AcademicReminderRestorationService(
      userId: account.userId,
      account: account,
      coordinator: coordinator,
      authRevision: authRevision,
      taskRepository: account.tasks,
      subjectRepository: account.subjects,
      classSessionRepository: account.sessions,
    );
  }

  final String _userId;
  final AcademicAccountScope? _account;
  final AcademicReminderOperationCoordinator coordinator;
  final int authRevision;

  void _ensureCurrent() {
    if (!coordinator.isCurrent(userId: _userId, revision: authRevision)) {
      throw StateError(
        'La restauración académica pertenece a una sesión obsoleta.',
      );
    }
  }

  final AcademicTaskRepository _taskRepository;
  final AcademicSubjectRepository _subjectRepository;
  final ClassSessionRepository _classSessionRepository;
  final AcademicTaskReminderService _taskReminderService;
  final ClassSessionReminderService _classSessionReminderService;

  Future<void> restore() async {
    _ensureCurrent();

    try {
      Future<List<Object>> readRepositories() {
        return Future.wait<Object>([
          _taskRepository.getAll(),
          _subjectRepository.getAll(),
          _classSessionRepository.getAll(),
        ]);
      }

      final account = _account;
      final results =
          account == null
              ? await readRepositories()
              : await account.run(readRepositories);

      // La cuenta pudo cambiar durante la lectura de SQLite.
      _ensureCurrent();

      final tasks = results[0] as List;
      final subjects = results[1] as List;
      final sessions = results[2] as List;

      final subjectsById = {
        for (final subject in subjects) subject.id as String: subject,
      };

      _ensureCurrent();
      await _taskReminderService.restore(tasks.cast());

      _ensureCurrent();
      await _classSessionReminderService.restore(
        sessions: sessions.cast(),
        subjectsById: subjectsById.cast(),
      );

      _ensureCurrent();

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
      rethrow;
    }
  }
}
