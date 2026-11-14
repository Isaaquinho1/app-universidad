import 'dart:async';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_verified_cancellation_service.dart';
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
  Completer<List<PendingNotificationRequest>>? pendingCompleter;
  bool failQuery = false;
  final cancelledIds = <int>[];

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (failQuery) throw StateError('Consulta fallida');
    if (pendingCompleter != null) return pendingCompleter!.future;
    return pending;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'student-A';
  const record = 'task-1';

  final id = AcademicReminderNotificationIdentity.forTask(
    userId: uid,
    taskId: record,
  );

  const ownPayload =
      '{"type":"academic_task","task_id":"task-1",'
      '"user_id":"student-A"}';

  late _FakeNotifications notifications;
  late AcademicReminderVerifiedCancellationService service;

  setUp(() {
    notifications = _FakeNotifications();
    service = AcademicReminderVerifiedCancellationService(
      localNotificationService: notifications,
    );
  });

  Future<void> check({void Function()? ensureCurrent}) {
    return service.ensureSlotAvailable(
      userId: uid,
      recordId: record,
      isTask: true,
      ensureCurrent: ensureCurrent,
    );
  }

  test('permite un ID libre', () async {
    await check();
    expect(notifications.cancelledIds, isEmpty);
  });

  test('permite actualizar la alarma propia', () async {
    notifications.pending = [_Pending(id, ownPayload)];
    await check();
    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza solicitudes duplicadas con el mismo propietario', () async {
    notifications.pending = [
      _Pending(id, ownPayload),
      _Pending(id, ownPayload),
    ];

    await expectLater(check(), throwsStateError);

    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza mezcla de alarma propia y comunicado con mismo ID', () async {
    notifications.pending = [
      _Pending(id, ownPayload),
      _Pending(id, '{"type":"announcement","announcement_id":"news-1"}'),
    ];

    await expectLater(check(), throwsStateError);

    expect(notifications.cancelledIds, isEmpty);
  });

  test('cancelOwned rechaza dos alarmas propias con el mismo ID', () async {
    notifications.pending = [
      _Pending(id, ownPayload),
      _Pending(id, ownPayload),
    ];

    await expectLater(
      service.cancelOwned(userId: uid, recordId: record, isTask: true),
      throwsStateError,
    );

    expect(notifications.cancelledIds, isEmpty);
  });

  test('cancelOwned no cancela una mezcla de alarma y comunicado', () async {
    notifications.pending = [
      _Pending(id, ownPayload),
      _Pending(id, '{"type":"announcement","announcement_id":"news-1"}'),
    ];

    await expectLater(
      service.cancelOwned(userId: uid, recordId: record, isTask: true),
      throwsStateError,
    );

    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza ID ocupado por otra cuenta', () async {
    notifications.pending = [
      _Pending(
        id,
        '{"type":"academic_task","task_id":"task-1",'
        '"user_id":"student-B"}',
      ),
    ];

    await expectLater(check(), throwsStateError);
    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza ID ocupado por comunicado institucional', () async {
    notifications.pending = [
      _Pending(id, '{"type":"announcement","announcement_id":"news-1"}'),
    ];

    await expectLater(check(), throwsStateError);
    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza un error al consultar notificaciones', () async {
    notifications.failQuery = true;

    await expectLater(check(), throwsStateError);
    expect(notifications.cancelledIds, isEmpty);
  });

  test('rechaza cambio de sesión durante la consulta', () async {
    notifications.pendingCompleter =
        Completer<List<PendingNotificationRequest>>();

    var current = true;

    void ensureCurrent() {
      if (!current) throw StateError('Sesión obsoleta');
    }

    final assertion = expectLater(
      check(ensureCurrent: ensureCurrent),
      throwsStateError,
    );

    current = false;
    notifications.pendingCompleter!.complete([]);

    await assertion;
    expect(notifications.cancelledIds, isEmpty);
  });
}
