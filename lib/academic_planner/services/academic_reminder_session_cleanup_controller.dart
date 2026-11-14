import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';

/// Controla la limpieza de alarmas académicas al cambiar de sesión.
///
/// No inicia limpiezas automáticamente. El llamador debe confirmar
/// que las notificaciones están listas y solicitar la operación.
class AcademicReminderSessionCleanupController {
  AcademicReminderSessionCleanupController({
    required this.coordinator,
    required this.cleanupService,
  });

  final AcademicReminderOperationCoordinator coordinator;
  final AcademicReminderPendingCleanupService cleanupService;

  bool _notificationsReady = false;

  final Map<(String, int), Future<bool>> _inFlight = {};
  final Map<(String, int), Future<bool>> _queuedRefresh = {};
  final Set<(String, int)> _completed = {};

  void markNotificationsReady() {
    _notificationsReady = true;
  }

  Future<bool> request({
    required String userId,
    required int authRevision,
    required bool authenticated,
    bool forceRefresh = false,
  }) {
    final uid = userId.trim();
    final key = (uid, authRevision);

    if (!_notificationsReady ||
        !authenticated ||
        uid.isEmpty ||
        !coordinator.isCurrent(userId: uid, revision: authRevision)) {
      return Future<bool>.value(false);
    }

    final queued = _queuedRefresh[key];
    if (queued != null) {
      return queued;
    }

    final existing = _inFlight[key];

    if (forceRefresh && existing != null) {
      final followUp = _runQueuedRefresh(
        previous: existing,
        userId: uid,
        revision: authRevision,
        key: key,
      );

      _queuedRefresh[key] = followUp;

      followUp.then<void>(
        (_) {
          if (identical(_queuedRefresh[key], followUp)) {
            _queuedRefresh.remove(key);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_queuedRefresh[key], followUp)) {
            _queuedRefresh.remove(key);
          }
        },
      );

      return followUp;
    }

    if (!forceRefresh && _completed.contains(key)) {
      return Future<bool>.value(true);
    }

    if (existing != null) {
      return existing;
    }

    final operation = _perform(uid, authRevision, key);
    _inFlight[key] = operation;

    // Liberar la entrada sin ocultar errores al solicitante.
    operation.then<void>(
      (_) {
        _inFlight.remove(key);
      },
      onError: (Object error, StackTrace stackTrace) {
        _inFlight.remove(key);
      },
    );

    return operation;
  }

  Future<bool> _runQueuedRefresh({
    required Future<bool> previous,
    required String userId,
    required int revision,
    required (String, int) key,
  }) async {
    try {
      await previous;
    } catch (_) {
      // La solicitud anterior conserva su propio resultado de error.
      // Una recuperación explícita puede volver a intentarse.
    }

    if (!_notificationsReady ||
        !coordinator.isCurrent(userId: userId, revision: revision)) {
      return false;
    }

    return _perform(userId, revision, key);
  }

  Future<bool> _perform(String userId, int revision, (String, int) key) async {
    final result = await coordinator.run(
      userId: userId,
      revision: revision,
      operation: (lease) async {
        lease.ensureCurrent();

        await cleanupService.cancelForeignAndLegacy(
          activeUserId: userId,
          ensureCurrent: lease.ensureCurrent,
        );

        lease.ensureCurrent();
      },
    );

    if (result) {
      _completed.add(key);
    }

    return result;
  }
}
