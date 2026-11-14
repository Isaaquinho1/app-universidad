import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';

/// Coordina limpieza y restauración sin anidar operaciones
/// sobre la misma cola de notificaciones académicas.
///
/// No se ejecuta automáticamente ni accede directamente a SQLite.
class AcademicReminderReconciliationOrchestrator {
  AcademicReminderReconciliationOrchestrator({required this.coordinator});

  final AcademicReminderOperationCoordinator coordinator;

  // Comparte las reconciliaciones simultáneas del mismo UID y revisión.
  final Map<(String, int), Future<bool>> _inFlight = {};

  // Serializa reconciliaciones completas, sin bloquear la cola académica.
  Future<void> _reconciliationTail = Future<void>.value();

  /// Devuelve false si la sesión dejó de estar vigente.
  ///
  /// Los errores operativos se propagan al llamador.
  Future<bool> reconcile({
    required String userId,
    required int authRevision,
    required Future<void> Function(AcademicReminderOperationLease lease)
    cleanup,
    required Future<void> Function() restore,
  }) async {
    final key = (userId, authRevision);

    final existing = _inFlight[key];
    if (existing != null) {
      return await existing;
    }

    final previous = _reconciliationTail;

    final operation = previous.then(
      (_) => _reconcile(
        userId: userId,
        authRevision: authRevision,
        cleanup: cleanup,
        restore: restore,
      ),
    );

    // Un fallo no bloquea las reconciliaciones posteriores.
    _reconciliationTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    _inFlight[key] = operation;

    try {
      return await operation;
    } finally {
      if (identical(_inFlight[key], operation)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<bool> _reconcile({
    required String userId,
    required int authRevision,
    required Future<void> Function(AcademicReminderOperationLease lease)
    cleanup,
    required Future<void> Function() restore,
  }) async {
    if (!coordinator.isCurrent(userId: userId, revision: authRevision)) {
      return false;
    }

    // Únicamente la limpieza ocupa esta operación de la cola.
    final cleanupCompleted = await coordinator.run(
      userId: userId,
      revision: authRevision,
      operation: (lease) async {
        lease.ensureCurrent();
        await cleanup(lease);
        lease.ensureCurrent();
      },
    );

    if (!cleanupCompleted ||
        !coordinator.isCurrent(userId: userId, revision: authRevision)) {
      return false;
    }

    // Nunca ejecutar restore() dentro del run() anterior:
    // los servicios de tareas y clases utilizan esta misma cola.
    await restore();

    return coordinator.isCurrent(userId: userId, revision: authRevision);
  }
}
