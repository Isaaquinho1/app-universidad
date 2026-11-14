import 'dart:async';

import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AcademicReminderOperationCoordinator coordinator;

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
  });

  test('serializa operaciones de la misma cuenta', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];

    final first = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        lease.ensureCurrent();
        order.add('inicio-A');
        started.complete();
        await release.future;
        lease.ensureCurrent();
        order.add('fin-A');
      },
    );

    await started.future;

    final second = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        lease.ensureCurrent();
        order.add('segunda-A');
      },
    );

    expect(order, ['inicio-A']);

    release.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(order, ['inicio-A', 'fin-A', 'segunda-A']);
  });

  test('omite operaciones obsoletas antes de ejecutarlas', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];

    final first = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        order.add('inicio-A');
        started.complete();
        await release.future;
      },
    );

    await started.future;

    final obsolete = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        order.add('A-obsoleta');
      },
    );

    coordinator.updateSession(userId: 'B', revision: 2);

    final current = coordinator.run(
      userId: 'B',
      revision: 2,
      operation: (lease) async {
        lease.ensureCurrent();
        order.add('B-vigente');
      },
    );

    expect(order, ['inicio-A']);

    release.complete();

    expect(await first, isFalse);
    expect(await obsolete, isFalse);
    expect(await current, isTrue);
    expect(order, ['inicio-A', 'B-vigente']);
  });

  test('A-B-A no reutiliza una revision anterior', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    coordinator.updateSession(userId: 'B', revision: 2);
    coordinator.updateSession(userId: 'A', revision: 3);

    var oldOperationRan = false;

    final old = await coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        oldOperationRan = true;
      },
    );

    final current = await coordinator.run(
      userId: 'A',
      revision: 3,
      operation: (lease) async {
        lease.ensureCurrent();
      },
    );

    expect(old, isFalse);
    expect(oldOperationRan, isFalse);
    expect(current, isTrue);
  });

  test('detecta invalidacion despues de un await', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final started = Completer<void>();
    final release = Completer<void>();
    var externalActionExecuted = false;

    final operation = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        lease.ensureCurrent();
        started.complete();

        await release.future;

        lease.ensureCurrent();
        externalActionExecuted = true;
      },
    );

    // Registrar el manejador de error antes de liberar la operación.
    final assertion = expectLater(operation, throwsStateError);

    await started.future;
    coordinator.updateSession(userId: 'B', revision: 2);
    release.complete();

    await assertion;

    expect(externalActionExecuted, isFalse);
    await coordinator.idle;
  });

  test('rechaza cuentas vacias y revisiones antiguas', () async {
    coordinator.updateSession(userId: null, revision: 0);

    expect(coordinator.isCurrent(userId: '', revision: 0), isFalse);

    expect(
      () => coordinator.updateSession(userId: 'A', revision: -1),
      throwsArgumentError,
    );

    coordinator.updateSession(userId: 'A', revision: 1);

    expect(
      () => coordinator.updateSession(userId: 'B', revision: 0),
      throwsArgumentError,
    );
  });
}
