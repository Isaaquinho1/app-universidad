import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';

/// Mantiene vivo un contexto académico durante la reconciliación de arranque.
///
/// No inicia operaciones automáticamente y no modifica SQLite al construirse.
class AcademicReminderStartupAccountRunner {
  AcademicReminderStartupAccountRunner({required this.coordinator});

  final AcademicReminderOperationCoordinator coordinator;

  final Map<(String, int), Future<bool>> _inFlight = {};

  /// Ejecuta una reconciliación con un contexto exclusivo de esta operación.
  ///
  /// El llamador proporciona la reconciliación existente.
  /// El contexto se invalida y cierra al terminar, incluso si hay un error.
  Future<bool> run({
    required String userId,
    required int authRevision,
    required Future<bool> Function(AcademicAccountScope account) reconcile,
  }) {
    final uid = userId.trim();

    if (uid.isEmpty ||
        !coordinator.isCurrent(userId: uid, revision: authRevision)) {
      return Future<bool>.value(false);
    }

    final key = (uid, authRevision);
    final existing = _inFlight[key];

    if (existing != null) {
      return existing;
    }

    final operation = _execute(
      userId: uid,
      authRevision: authRevision,
      reconcile: reconcile,
    );

    _inFlight[key] = operation;

    operation.then<void>(
      (_) {
        if (identical(_inFlight[key], operation)) {
          _inFlight.remove(key);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_inFlight[key], operation)) {
          _inFlight.remove(key);
        }
      },
    );

    return operation;
  }

  Future<bool> _execute({
    required String userId,
    required int authRevision,
    required Future<bool> Function(AcademicAccountScope account) reconcile,
  }) async {
    if (!coordinator.isCurrent(userId: userId, revision: authRevision)) {
      return false;
    }

    final account = AcademicAccountScope.forUser(userId);

    try {
      if (!coordinator.isCurrent(userId: userId, revision: authRevision)) {
        return false;
      }

      final result = await reconcile(account);

      return result &&
          coordinator.isCurrent(userId: userId, revision: authRevision);
    } finally {
      // Nunca cerrar SQLite mientras la restauración sigue ejecutándose.
      // close() espera las operaciones registradas en AcademicAccountScope.
      account.invalidate();
      await account.close();
    }
  }
}
