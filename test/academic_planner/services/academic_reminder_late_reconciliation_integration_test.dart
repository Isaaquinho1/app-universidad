import 'dart:async';
import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pending implements PendingNotificationRequest {
  _Pending(this.id, this.payload);

  @override
  final int id;

  @override
  final String? payload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements LocalNotificationService {
  final pending = <PendingNotificationRequest>[];
  final cancelled = <int>[];

  int queries = 0;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    queries++;
    return List.of(pending);
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
    pending.removeWhere((request) => request.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_Pending _task(String uid, String id) {
  return _Pending(
    AcademicReminderNotificationIdentity.forTask(userId: uid, taskId: id),
    jsonEncode({'type': 'academic_task', 'task_id': id, 'user_id': uid}),
  );
}

void main() {
  test('B espera programación tardía de A antes de limpiar', () async {
    final coordinator =
        AcademicReminderOperationCoordinator()
          ..updateSession(userId: 'A', revision: 1);

    final orchestrator = AcademicReminderReconciliationOrchestrator(
      coordinator: coordinator,
    );

    final notifications = _Notifications();
    final cleanup = AcademicReminderPendingCleanupService(
      localNotificationService: notifications,
    );

    final ownB = _task('B', 'task-own');
    final announcement = _Pending(
      0x50000001,
      jsonEncode({'type': 'announcement', 'announcement_id': 'news-1'}),
    );

    notifications.pending.addAll([ownB, announcement]);

    final started = Completer<void>();
    final release = Completer<void>();
    final lateA = _task('A', 'task-late');

    // Simula una programación de A que ya fue iniciada
    // y cuyo resultado llega después del cambio de cuenta.
    final schedulingA = coordinator.run(
      userId: 'A',
      revision: 1,
      operation: (lease) async {
        lease.ensureCurrent();
        started.complete();

        await release.future;

        // Simula que el plugin aceptó la programación.
        notifications.pending.add(lateA);

        // El servicio detecta que A ya no está vigente.
        lease.ensureCurrent();
      },
    );

    final oldSessionAssertion = expectLater(schedulingA, throwsStateError);

    await started.future;

    coordinator.updateSession(userId: 'B', revision: 2);

    var restoredB = false;
    var cleanupStarted = false;

    final reconciliationB = orchestrator.reconcile(
      userId: 'B',
      authRevision: 2,
      cleanup: (lease) async {
        cleanupStarted = true;

        await cleanup.cancelForeignAndLegacy(
          activeUserId: 'B',
          ensureCurrent: lease.ensureCurrent,
        );
      },
      restore: () async {
        restoredB = true;
      },
    );

    // La reconciliación de B no puede adelantar
    // a la operación de programación pendiente de A.
    await Future<void>.delayed(Duration.zero);

    expect(cleanupStarted, isFalse);
    expect(notifications.queries, 0);
    expect(notifications.cancelled, isEmpty);

    release.complete();

    await oldSessionAssertion;

    expect(await reconciliationB, isTrue);

    expect(cleanupStarted, isTrue);
    expect(restoredB, isTrue);

    // Solamente se retira la alarma tardía de A.
    expect(notifications.cancelled, [lateA.id]);

    // La tarea de B y el comunicado institucional permanecen.
    expect(
      notifications.pending.map((request) => request.id),
      containsAll([ownB.id, announcement.id]),
    );

    expect(
      notifications.pending.map((request) => request.id),
      isNot(contains(lateA.id)),
    );
  });
}
