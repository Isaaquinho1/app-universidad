import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_verified_cancellation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'student-A';
  const taskId = 'task-1';
  const signature = 'configuracion-actual';

  final expectedId = AcademicReminderNotificationIdentity.forTask(
    userId: uid,
    taskId: taskId,
  );

  String payload({
    String owner = uid,
    String record = taskId,
    String type = 'academic_task',
    String scheduleSignature = signature,
    bool includeSignature = true,
  }) {
    return jsonEncode({
      'type': type,
      'user_id': owner,
      'task_id': record,
      if (includeSignature) ...{
        AcademicReminderScheduleIdentity.versionKey:
            AcademicReminderScheduleIdentity.version,
        AcademicReminderScheduleIdentity.signatureKey: scheduleSignature,
      },
    });
  }

  bool matches({required int id, required String? data}) {
    return AcademicReminderVerifiedCancellationService.isMatchingSchedule(
      id: id,
      payload: data,
      userId: uid,
      recordId: taskId,
      isTask: true,
      expectedSignature: signature,
    );
  }

  test('alarma propia con firma actual coincide', () {
    expect(matches(id: expectedId, data: payload()), isTrue);
  });

  test('firma diferente no coincide', () {
    expect(
      matches(
        id: expectedId,
        data: payload(scheduleSignature: 'configuracion-anterior'),
      ),
      isFalse,
    );
  });

  test('firma correcta de otro usuario no acredita propiedad', () {
    expect(matches(id: expectedId, data: payload(owner: 'student-B')), isFalse);
  });

  test('registro diferente no acredita propiedad', () {
    expect(matches(id: expectedId, data: payload(record: 'task-2')), isFalse);
  });

  test('ID diferente no acredita propiedad', () {
    expect(matches(id: expectedId + 1, data: payload()), isFalse);
  });

  test('notificación institucional no coincide', () {
    expect(
      matches(id: expectedId, data: payload(type: 'announcement')),
      isFalse,
    );
  });

  test('payload heredado sin firma no coincide', () {
    expect(
      matches(id: expectedId, data: payload(includeSignature: false)),
      isFalse,
    );
  });

  test('payload malformado no coincide', () {
    expect(matches(id: expectedId, data: '{invalido'), isFalse);
  });
}
