import 'package:conecta_itt/academic_planner/services/academic_reminder_account_reconciler.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_restoration_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cleanup implements AcademicReminderPendingCleanupService {
  _Cleanup(this.steps);

  final List<String> steps;
  bool fail = false;

  @override
  Future<int> cancelForeignAndLegacy({
    required String activeUserId,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    steps.add('cleanup:$activeUserId');

    if (fail) throw StateError('Error de limpieza');

    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Restoration implements AcademicReminderRestorationService {
  _Restoration(this.steps);

  final List<String> steps;
  bool fail = false;

  @override
  Future<void> restore() async {
    steps.add('restore');

    if (fail) throw StateError('Error de restauración');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AcademicReminderOperationCoordinator coordinator;
  late AcademicReminderReconciliationOrchestrator orchestrator;
  late List<String> steps;
  late _Cleanup cleanup;
  late _Restoration restoration;

  AcademicReminderAccountReconciler create(String userId, int revision) {
    return AcademicReminderAccountReconciler(
      userId: userId,
      authRevision: revision,
      coordinator: coordinator,
      orchestrator: orchestrator,
      cleanupService: cleanup,
      restorationService: restoration,
    );
  }

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );
    steps = [];
    cleanup = _Cleanup(steps);
    restoration = _Restoration(steps);
  });

  test('limpia y después restaura la cuenta activa', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final result = await create('A', 1).reconcile();

    expect(result, isTrue);
    expect(steps, ['cleanup:A', 'restore']);
  });

  test('una sesión antigua no ejecuta operaciones', () async {
    coordinator.updateSession(userId: 'B', revision: 2);

    final result = await create('A', 1).reconcile();

    expect(result, isFalse);
    expect(steps, isEmpty);
  });

  test('un error de limpieza impide restaurar', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    cleanup.fail = true;

    await expectLater(create('A', 1).reconcile(), throwsStateError);

    expect(steps, ['cleanup:A']);
  });

  test('un error de restauración se propaga', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    restoration.fail = true;

    await expectLater(create('A', 1).reconcile(), throwsStateError);

    expect(steps, ['cleanup:A', 'restore']);
  });

  test('rechaza un orquestador con otro coordinador', () {
    final other = AcademicReminderReconciliationOrchestrator(
      coordinator: AcademicReminderOperationCoordinator(),
    );

    expect(
      () => AcademicReminderAccountReconciler(
        userId: 'A',
        authRevision: 1,
        coordinator: coordinator,
        orchestrator: other,
        cleanupService: cleanup,
        restorationService: restoration,
      ),
      throwsArgumentError,
    );
  });
}
