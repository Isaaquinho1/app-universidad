import 'dart:async';
import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
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

class _FakeNotifications implements LocalNotificationService {
  List<PendingNotificationRequest> pending = [];
  final cancelledIds = <int>[];

  Completer<List<PendingNotificationRequest>>? pendingCompleter;
  Completer<void>? firstCancellationStarted;
  Completer<void>? releaseFirstCancellation;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    final waiting = pendingCompleter;
    if (waiting != null) return waiting.future;
    return pending;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);

    if (cancelledIds.length == 1 && releaseFirstCancellation != null) {
      firstCancellationStarted?.complete();
      await releaseFirstCancellation!.future;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  _Pending task(String uid, String taskId) {
    return _Pending(
      AcademicReminderNotificationIdentity.forTask(userId: uid, taskId: taskId),
      jsonEncode({'type': 'academic_task', 'task_id': taskId, 'user_id': uid}),
    );
  }

  test('limpia solamente alarmas ajenas verificadas', () async {
    final fake = _FakeNotifications();

    final foreign = task('B', 'task-1');
    final own = task('A', 'task-2');

    fake.pending = [foreign, own, _Pending(123456, '{"type":"announcement"}')];

    final service = AcademicReminderPendingCleanupService(
      localNotificationService: fake,
    );

    final cancelled = await service.cancelForeignAndLegacy(activeUserId: 'A');

    expect(cancelled, 1);
    expect(fake.cancelledIds, [foreign.id]);
  });

  test('una sesión invalidada durante consulta no cancela', () async {
    final fake = _FakeNotifications();
    fake.pendingCompleter = Completer<List<PendingNotificationRequest>>();

    final service = AcademicReminderPendingCleanupService(
      localNotificationService: fake,
    );

    var current = true;

    void ensureCurrent() {
      if (!current) throw StateError('Sesión obsoleta');
    }

    final operation = service.cancelForeignAndLegacy(
      activeUserId: 'A',
      ensureCurrent: ensureCurrent,
    );

    final assertion = expectLater(operation, throwsStateError);

    current = false;
    fake.pendingCompleter!.complete([task('B', 'task-1')]);

    await assertion;
    expect(fake.cancelledIds, isEmpty);
  });

  test('invalidación entre cancelaciones detiene limpieza', () async {
    final fake = _FakeNotifications();

    final first = task('B', 'task-1');
    final second = task('C', 'task-2');

    fake.pending = [first, second];
    fake.firstCancellationStarted = Completer<void>();
    fake.releaseFirstCancellation = Completer<void>();

    final service = AcademicReminderPendingCleanupService(
      localNotificationService: fake,
    );

    var current = true;

    void ensureCurrent() {
      if (!current) throw StateError('Sesión obsoleta');
    }

    final operation = service.cancelForeignAndLegacy(
      activeUserId: 'A',
      ensureCurrent: ensureCurrent,
    );

    final assertion = expectLater(operation, throwsStateError);

    await fake.firstCancellationStarted!.future;

    current = false;
    fake.releaseFirstCancellation!.complete();

    await assertion;

    expect(fake.cancelledIds, [first.id]);
    expect(fake.cancelledIds, isNot(contains(second.id)));
  });

  test(
    'coordinador espera cancelación antes de iniciar otra operación',
    () async {
      final coordinator =
          AcademicReminderOperationCoordinator()
            ..updateSession(userId: 'A', revision: 1);

      final fake = _FakeNotifications();
      final foreign = task('B', 'task-pending');

      fake.pending = [foreign];
      fake.firstCancellationStarted = Completer<void>();
      fake.releaseFirstCancellation = Completer<void>();

      final cleanup = AcademicReminderPendingCleanupService(
        localNotificationService: fake,
      );

      final first = coordinator.run(
        userId: 'A',
        revision: 1,
        operation: (lease) async {
          await cleanup.cancelForeignAndLegacy(
            activeUserId: 'A',
            ensureCurrent: lease.ensureCurrent,
          );
        },
      );

      // La primera operación ya llegó al plugin de cancelación.
      await fake.firstCancellationStarted!.future;

      var secondStarted = false;

      final second = coordinator.run(
        userId: 'A',
        revision: 1,
        operation: (lease) async {
          secondStarted = true;
          lease.ensureCurrent();
        },
      );

      // Aunque cedamos un turno al event loop, la segunda
      // operación no debe adelantarse a la cancelación pendiente.
      await Future<void>.delayed(Duration.zero);

      expect(secondStarted, isFalse);

      fake.releaseFirstCancellation!.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(secondStarted, isTrue);
      expect(fake.cancelledIds, [foreign.id]);
    },
  );
}
