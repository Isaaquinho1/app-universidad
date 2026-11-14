import 'dart:async';

import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AcademicReminderOperationCoordinator coordinator;
  late AcademicReminderReconciliationOrchestrator orchestrator;

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );
  });

  test('ejecuta limpieza antes de restauración', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final steps = <String>[];

    final result = await orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (lease) async {
        lease.ensureCurrent();
        steps.add('cleanup');
      },
      restore: () async {
        steps.add('restore');
      },
    );

    expect(result, isTrue);
    expect(steps, ['cleanup', 'restore']);
  });

  test('A-B-A descarta una revisión antigua', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    coordinator.updateSession(userId: 'B', revision: 2);
    coordinator.updateSession(userId: 'A', revision: 3);

    var called = false;

    final result = await orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (_) async => called = true,
      restore: () async => called = true,
    );

    expect(result, isFalse);
    expect(called, isFalse);
  });

  test('cambio de sesión durante limpieza impide restaurar', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    var restored = false;

    final operation = orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (lease) async {
        started.complete();
        await release.future;
        lease.ensureCurrent();
      },
      restore: () async {
        restored = true;
      },
    );

    final assertion = expectLater(operation, throwsStateError);

    await started.future;
    coordinator.updateSession(userId: 'B', revision: 2);
    release.complete();

    await assertion;
    expect(restored, isFalse);
  });

  test('restauración puede usar la misma cola sin bloqueo', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final steps = <String>[];

    final result = await orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (_) async {
        steps.add('cleanup');
      },
      restore: () async {
        final executed = await coordinator.run(
          userId: 'A',
          revision: 1,
          operation: (_) async {
            steps.add('restore');
          },
        );
        expect(executed, isTrue);
      },
    );

    expect(result, isTrue);
    expect(steps, ['cleanup', 'restore']);
  });

  test('solicitudes simultáneas comparten la reconciliación', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    var cleanups = 0;
    var restorations = 0;

    Future<bool> request() {
      return orchestrator.reconcile(
        userId: 'A',
        authRevision: 1,
        cleanup: (_) async {
          cleanups++;
          if (!started.isCompleted) started.complete();
          await release.future;
        },
        restore: () async {
          restorations++;
        },
      );
    }

    final first = request();
    await started.future;

    final second = request();
    release.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(cleanups, 1);
    expect(restorations, 1);
  });

  test('una reconciliación fallida permite reintento', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    var attempts = 0;

    Future<bool> request() {
      return orchestrator.reconcile(
        userId: 'A',
        authRevision: 1,
        cleanup: (_) async {
          attempts++;
        },
        restore: () async {
          if (attempts == 1) {
            throw StateError('Fallo simulado');
          }
        },
      );
    }

    await expectLater(request(), throwsStateError);

    expect(await request(), isTrue);
    expect(attempts, 2);
  });

  test('B espera a que termine la restauración de A', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final restoreStarted = Completer<void>();
    final releaseRestore = Completer<void>();
    final steps = <String>[];

    final first = orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (_) async {
        steps.add('cleanup-A');
      },
      restore: () async {
        steps.add('restore-A-start');
        restoreStarted.complete();
        await releaseRestore.future;
        steps.add('restore-A-end');
      },
    );

    await restoreStarted.future;

    coordinator.updateSession(userId: 'B', revision: 2);

    final second = orchestrator.reconcile(
      userId: 'B',
      authRevision: 2,
      cleanup: (_) async {
        steps.add('cleanup-B');
      },
      restore: () async {
        steps.add('restore-B');
      },
    );

    await Future<void>.delayed(Duration.zero);

    expect(steps, ['cleanup-A', 'restore-A-start']);

    releaseRestore.complete();

    expect(await first, isFalse);
    expect(await second, isTrue);

    expect(steps, [
      'cleanup-A',
      'restore-A-start',
      'restore-A-end',
      'cleanup-B',
      'restore-B',
    ]);
  });

  test('un fallo en A no bloquea la reconciliación de B', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final first = orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (_) async {},
      restore: () async {
        throw StateError('Error simulado en A');
      },
    );

    await expectLater(first, throwsStateError);

    coordinator.updateSession(userId: 'B', revision: 2);

    final steps = <String>[];

    final result = await orchestrator.reconcile(
      userId: 'B',
      authRevision: 2,
      cleanup: (_) async {
        steps.add('cleanup-B');
      },
      restore: () async {
        steps.add('restore-B');
      },
    );

    expect(result, isTrue);
    expect(steps, ['cleanup-B', 'restore-B']);
  });

  test('A-B-C descarta una reconciliación que esperaba en cola', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    final steps = <String>[];

    final first = orchestrator.reconcile(
      userId: 'A',
      authRevision: 1,
      cleanup: (_) async {
        steps.add('cleanup-A');
      },
      restore: () async {
        steps.add('restore-A-start');
        started.complete();
        await release.future;
        steps.add('restore-A-end');
      },
    );

    await started.future;

    coordinator.updateSession(userId: 'B', revision: 2);

    final second = orchestrator.reconcile(
      userId: 'B',
      authRevision: 2,
      cleanup: (_) async {
        steps.add('cleanup-B');
      },
      restore: () async {
        steps.add('restore-B');
      },
    );

    coordinator.updateSession(userId: 'C', revision: 3);

    final third = orchestrator.reconcile(
      userId: 'C',
      authRevision: 3,
      cleanup: (_) async {
        steps.add('cleanup-C');
      },
      restore: () async {
        steps.add('restore-C');
      },
    );

    release.complete();

    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(await third, isTrue);

    expect(steps, [
      'cleanup-A',
      'restore-A-start',
      'restore-A-end',
      'cleanup-C',
      'restore-C',
    ]);
  });

  test('un fallo parcial permite reintento explícito', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    var cleanups = 0;
    var restorations = 0;

    Future<bool> request() {
      return orchestrator.reconcile(
        userId: 'A',
        authRevision: 1,
        cleanup: (_) async {
          cleanups++;
        },
        restore: () async {
          restorations++;

          if (restorations == 1) {
            throw StateError('Restauración incompleta simulada');
          }
        },
      );
    }

    await expectLater(request(), throwsStateError);

    expect(await request(), isTrue);
    expect(cleanups, 2);
    expect(restorations, 2);
  });

  test('error de restauración se propaga', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    await expectLater(
      orchestrator.reconcile(
        userId: 'A',
        authRevision: 1,
        cleanup: (_) async {},
        restore: () async {
          throw StateError('Restauración fallida');
        },
      ),
      throwsStateError,
    );
  });
}
