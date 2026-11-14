import 'dart:async';

import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_session_cleanup_controller.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Notifications implements LocalNotificationService {
  int queries = 0;
  int cancellations = 0;
  bool failNext = false;

  Completer<void>? queryStarted;
  Completer<void>? releaseQuery;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    queries++;
    queryStarted?.complete();

    final release = releaseQuery;
    if (release != null) {
      await release.future;
    }

    if (failNext) {
      failNext = false;
      throw StateError('Consulta simulada fallida');
    }

    return <PendingNotificationRequest>[];
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancellations++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AcademicReminderOperationCoordinator coordinator;
  late _Notifications notifications;
  late AcademicReminderSessionCleanupController controller;

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    notifications = _Notifications();
    controller = AcademicReminderSessionCleanupController(
      coordinator: coordinator,
      cleanupService: AcademicReminderPendingCleanupService(
        localNotificationService: notifications,
      ),
    );
  });

  test('no limpia antes de inicializar notificaciones', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final result = await controller.request(
      userId: 'A',
      authRevision: 1,
      authenticated: true,
    );

    expect(result, isFalse);
    expect(notifications.queries, 0);

    controller.markNotificationsReady();

    expect(
      await controller.request(
        userId: 'A',
        authRevision: 1,
        authenticated: true,
      ),
      isTrue,
    );

    expect(notifications.queries, 1);
  });

  test('rechaza sesión obsoleta o no autenticada', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'B', revision: 2);

    expect(
      await controller.request(
        userId: 'A',
        authRevision: 1,
        authenticated: true,
      ),
      isFalse,
    );

    expect(
      await controller.request(
        userId: 'B',
        authRevision: 2,
        authenticated: false,
      ),
      isFalse,
    );

    expect(notifications.queries, 0);
  });

  test('solicitudes simultáneas comparten una consulta', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'B', revision: 2);

    notifications.queryStarted = Completer<void>();
    notifications.releaseQuery = Completer<void>();

    final first = controller.request(
      userId: 'B',
      authRevision: 2,
      authenticated: true,
    );

    await notifications.queryStarted!.future;

    final second = controller.request(
      userId: 'B',
      authRevision: 2,
      authenticated: true,
    );

    expect(identical(first, second), isTrue);
    expect(notifications.queries, 1);

    notifications.releaseQuery!.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(notifications.queries, 1);
  });

  test('un error permite reintento explícito', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'B', revision: 2);

    notifications.failNext = true;

    await expectLater(
      controller.request(userId: 'B', authRevision: 2, authenticated: true),
      throwsStateError,
    );

    expect(
      await controller.request(
        userId: 'B',
        authRevision: 2,
        authenticated: true,
      ),
      isTrue,
    );

    expect(notifications.queries, 2);
  });

  test('limpieza explícita puede repetirse tras completarse', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'B', revision: 2);

    Future<bool> request({bool forceRefresh = false}) {
      return controller.request(
        userId: 'B',
        authRevision: 2,
        authenticated: true,
        forceRefresh: forceRefresh,
      );
    }

    expect(await request(), isTrue);
    expect(notifications.queries, 1);

    // Una petición normal no repite la limpieza.
    expect(await request(), isTrue);
    expect(notifications.queries, 1);

    // Una solicitud explícita sí vuelve a comprobar pendientes.
    expect(await request(forceRefresh: true), isTrue);
    expect(notifications.queries, 2);

    expect(await request(), isTrue);
    expect(notifications.queries, 2);
  });

  test('limpieza forzada rechaza una sesión anterior', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'A', revision: 1);

    expect(
      await controller.request(
        userId: 'A',
        authRevision: 1,
        authenticated: true,
      ),
      isTrue,
    );

    coordinator.updateSession(userId: 'B', revision: 2);

    expect(
      await controller.request(
        userId: 'A',
        authRevision: 1,
        authenticated: true,
        forceRefresh: true,
      ),
      isFalse,
    );

    expect(notifications.queries, 1);
  });

  test('forceRefresh durante limpieza ejecuta otra consulta', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'B', revision: 2);

    notifications.queryStarted = Completer<void>();
    notifications.releaseQuery = Completer<void>();

    Future<bool> request({bool forceRefresh = false}) {
      return controller.request(
        userId: 'B',
        authRevision: 2,
        authenticated: true,
        forceRefresh: forceRefresh,
      );
    }

    final first = request();
    await notifications.queryStarted!.future;

    // La segunda consulta no debe completar otra vez el mismo Completer.
    notifications.queryStarted = null;

    final forcedOne = request(forceRefresh: true);
    final forcedTwo = request(forceRefresh: true);

    expect(identical(forcedOne, forcedTwo), isTrue);

    await Future<void>.delayed(Duration.zero);
    expect(notifications.queries, 1);

    notifications.releaseQuery!.complete();

    expect(await first, isTrue);
    expect(await forcedOne, isTrue);
    expect(await forcedTwo, isTrue);
    expect(notifications.queries, 2);

    // Después de ambas limpiezas, una solicitud normal no repite.
    expect(await request(), isTrue);
    expect(notifications.queries, 2);
  });

  test('recuperación encolada se descarta si cambia la sesión', () async {
    controller.markNotificationsReady();
    coordinator.updateSession(userId: 'A', revision: 1);

    notifications.queryStarted = Completer<void>();
    notifications.releaseQuery = Completer<void>();

    final first = controller.request(
      userId: 'A',
      authRevision: 1,
      authenticated: true,
    );

    final firstAssertion = expectLater(first, throwsStateError);

    await notifications.queryStarted!.future;
    notifications.queryStarted = null;

    final forced = controller.request(
      userId: 'A',
      authRevision: 1,
      authenticated: true,
      forceRefresh: true,
    );

    coordinator.updateSession(userId: 'B', revision: 2);

    notifications.releaseQuery!.complete();

    await firstAssertion;

    expect(await forced, isFalse);
    expect(notifications.queries, 1);
    expect(notifications.cancellations, 0);
  });

  test('A-B-A distingue las revisiones de autenticación', () async {
    controller.markNotificationsReady();

    Future<bool> request(String uid, int revision) {
      return controller.request(
        userId: uid,
        authRevision: revision,
        authenticated: true,
      );
    }

    coordinator.updateSession(userId: 'A', revision: 1);
    expect(await request('A', 1), isTrue);

    coordinator.updateSession(userId: 'B', revision: 2);
    expect(await request('B', 2), isTrue);
    expect(await request('A', 1), isFalse);

    coordinator.updateSession(userId: 'A', revision: 3);
    expect(await request('A', 3), isTrue);

    // Repetir una sesión ya completada no duplica la consulta.
    expect(await request('A', 3), isTrue);

    expect(notifications.queries, 3);
    expect(notifications.cancellations, 0);
  });
}
