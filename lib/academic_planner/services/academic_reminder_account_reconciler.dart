import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_restoration_service.dart';

/// Conecta limpieza y restauración de una cuenta académica.
///
/// No inicia operaciones automáticamente. Debe compartir la misma
/// instancia de orquestador y coordinador que el ciclo de autenticación.
class AcademicReminderAccountReconciler {
  AcademicReminderAccountReconciler({
    required this.userId,
    required this.authRevision,
    required this.coordinator,
    required this.orchestrator,
    required this.cleanupService,
    required this.restorationService,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
    if (authRevision < 0) {
      throw ArgumentError.value(authRevision, 'authRevision');
    }
    if (!identical(orchestrator.coordinator, coordinator)) {
      throw ArgumentError(
        'El orquestador debe utilizar el coordinador compartido.',
      );
    }
  }

  factory AcademicReminderAccountReconciler.forAccount({
    required AcademicAccountScope account,
    required int authRevision,
    required AcademicReminderOperationCoordinator coordinator,
    required AcademicReminderReconciliationOrchestrator orchestrator,
  }) {
    return AcademicReminderAccountReconciler(
      userId: account.userId,
      authRevision: authRevision,
      coordinator: coordinator,
      orchestrator: orchestrator,
      cleanupService: AcademicReminderPendingCleanupService(),
      restorationService: AcademicReminderRestorationService.forAccount(
        account,
        coordinator: coordinator,
        authRevision: authRevision,
      ),
    );
  }

  final String userId;
  final int authRevision;
  final AcademicReminderOperationCoordinator coordinator;
  final AcademicReminderReconciliationOrchestrator orchestrator;
  final AcademicReminderPendingCleanupService cleanupService;
  final AcademicReminderRestorationService restorationService;

  /// True indica que la sesión seguía vigente al finalizar.
  ///
  /// Las excepciones de limpieza o restauración se propagan.
  Future<bool> reconcile() {
    return orchestrator.reconcile(
      userId: userId,
      authRevision: authRevision,
      cleanup: (lease) async {
        lease.ensureCurrent();

        await cleanupService.cancelForeignAndLegacy(
          activeUserId: userId,
          ensureCurrent: lease.ensureCurrent,
        );

        lease.ensureCurrent();
      },
      restore: () async {
        if (!coordinator.isCurrent(userId: userId, revision: authRevision)) {
          throw StateError('Sesión académica obsoleta.');
        }

        await restorationService.restore();
      },
    );
  }
}
