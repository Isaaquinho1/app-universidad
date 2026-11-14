import 'dart:async';
import 'package:conecta_itt/academic_planner/services/academic_reminder_account_reconciler.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_restoration_service.dart';

import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_startup_account_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _StartupCleanup implements AcademicReminderPendingCleanupService {
  _StartupCleanup(this.steps);

  final List<String> steps;
  bool fail = false;

  @override
  Future<int> cancelForeignAndLegacy({
    required String activeUserId,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    steps.add('cleanup:$activeUserId');

    if (fail) {
      throw StateError('Limpieza simulada fallida');
    }

    ensureCurrent?.call();
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StartupRestoration implements AcademicReminderRestorationService {
  _StartupRestoration(this.steps);

  final List<String> steps;

  @override
  Future<void> restore() async {
    steps.add('restore');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AcademicReminderOperationCoordinator coordinator;
  late AcademicReminderStartupAccountRunner runner;

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    runner = AcademicReminderStartupAccountRunner(coordinator: coordinator);
  });

  test('rechaza una sesión obsoleta sin abrir contexto', () async {
    coordinator.updateSession(userId: 'B', revision: 2);

    var invoked = false;

    final result = await runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: (_) async {
        invoked = true;
        return true;
      },
    );

    expect(result, isFalse);
    expect(invoked, isFalse);
  });

  test('deduplica solicitudes simultáneas de la misma sesión', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;

    Future<bool> reconcile(dynamic account) async {
      calls++;
      started.complete();
      await release.future;
      return true;
    }

    final first = runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: reconcile,
    );

    await started.future;

    final second = runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: reconcile,
    );

    expect(identical(first, second), isTrue);
    expect(calls, 1);

    release.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(calls, 1);
  });

  test('invalida resultado si cambia la sesión durante la operación', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();

    final operation = runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: (_) async {
        started.complete();
        await release.future;
        return true;
      },
    );

    await started.future;

    coordinator.updateSession(userId: 'B', revision: 2);
    release.complete();

    expect(await operation, isFalse);
  });

  test('runner conecta el reconciliador real sin duplicar limpieza', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final steps = <String>[];
    final cleanup = _StartupCleanup(steps);
    final restoration = _StartupRestoration(steps);
    final orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );

    var constructions = 0;

    final result = await runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: (account) {
        constructions++;

        return AcademicReminderAccountReconciler(
          userId: account.userId,
          authRevision: 1,
          coordinator: coordinator,
          orchestrator: orchestrator,
          cleanupService: cleanup,
          restorationService: restoration,
        ).reconcile();
      },
    );

    expect(result, isTrue);
    expect(constructions, 1);
    expect(steps, ['cleanup:A', 'restore']);
  });

  test(
    'runner no restaura si falla la limpieza del reconciliador real',
    () async {
      coordinator.updateSession(userId: 'A', revision: 1);

      final steps = <String>[];
      final cleanup = _StartupCleanup(steps)..fail = true;
      final restoration = _StartupRestoration(steps);
      final orchestrator = AcademicReminderReconciliationOrchestrator(
        coordinator: coordinator,
      );

      Future<bool> execute() {
        return runner.run(
          userId: 'A',
          authRevision: 1,
          reconcile: (account) {
            return AcademicReminderAccountReconciler(
              userId: account.userId,
              authRevision: 1,
              coordinator: coordinator,
              orchestrator: orchestrator,
              cleanupService: cleanup,
              restorationService: restoration,
            ).reconcile();
          },
        );
      }

      await expectLater(execute(), throwsStateError);

      expect(steps, ['cleanup:A']);

      cleanup.fail = false;

      final retry = await execute();

      expect(retry, isTrue);
      expect(steps, ['cleanup:A', 'cleanup:A', 'restore']);
    },
  );

  test('ejecuta limpieza antes de restaurar', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );
    final sequence = <String>[];

    final result = await runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile:
          (account) => orchestrator.reconcile(
            userId: account.userId,
            authRevision: 1,
            cleanup: (lease) async {
              lease.ensureCurrent();
              sequence.add('cleanup');
            },
            restore: () async {
              sequence.add('restore');
            },
          ),
    );

    expect(result, isTrue);
    expect(sequence, ['cleanup', 'restore']);
  });

  test('un fallo de limpieza impide restaurar y admite reintento', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );

    var restoreCalls = 0;

    await expectLater(
      runner.run(
        userId: 'A',
        authRevision: 1,
        reconcile:
            (account) => orchestrator.reconcile(
              userId: account.userId,
              authRevision: 1,
              cleanup: (lease) async {
                lease.ensureCurrent();
                throw StateError('Limpieza simulada fallida');
              },
              restore: () async {
                restoreCalls++;
              },
            ),
      ),
      throwsStateError,
    );

    expect(restoreCalls, 0);

    final retry = await runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile:
          (account) => orchestrator.reconcile(
            userId: account.userId,
            authRevision: 1,
            cleanup: (lease) async {
              lease.ensureCurrent();
            },
            restore: () async {
              restoreCalls++;
            },
          ),
    );

    expect(retry, isTrue);
    expect(restoreCalls, 1);
  });

  test('propaga errores y permite solicitudes posteriores', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    await expectLater(
      runner.run(
        userId: 'A',
        authRevision: 1,
        reconcile: (_) async {
          throw StateError('Error simulado');
        },
      ),
      throwsStateError,
    );

    final recovered = await runner.run(
      userId: 'A',
      authRevision: 1,
      reconcile: (_) async => true,
    );

    expect(recovered, isTrue);
  });
}
