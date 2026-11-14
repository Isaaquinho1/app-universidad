import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('misma tarea genera firma determinista', () {
    final date = DateTime(2026, 11, 5, 10, 30);

    final first = AcademicReminderScheduleIdentity.forTask(
      title: 'Proyecto final',
      scheduledAt: date,
    );

    final second = AcademicReminderScheduleIdentity.forTask(
      title: 'Proyecto final',
      scheduledAt: date,
    );

    expect(first, second);
  });

  test('cambiar fecha o título modifica firma de tarea', () {
    final original = AcademicReminderScheduleIdentity.forTask(
      title: 'Proyecto final',
      scheduledAt: DateTime(2026, 11, 5, 10, 30),
    );

    final changedDate = AcademicReminderScheduleIdentity.forTask(
      title: 'Proyecto final',
      scheduledAt: DateTime(2026, 11, 5, 11, 30),
    );

    final changedTitle = AcademicReminderScheduleIdentity.forTask(
      title: 'Otro proyecto',
      scheduledAt: DateTime(2026, 11, 5, 10, 30),
    );

    expect(changedDate, isNot(original));
    expect(changedTitle, isNot(original));
  });

  test('cambiar horario o contenido modifica firma de clase', () {
    String signature({required int hour, required String body}) {
      return AcademicReminderScheduleIdentity.forClassSession(
        body: body,
        weekday: DateTime.monday,
        hour: hour,
        minute: 15,
      );
    }

    final original = signature(hour: 8, body: 'Redes · A101');

    expect(signature(hour: 9, body: 'Redes · A101'), isNot(original));
    expect(signature(hour: 8, body: 'Redes · B202'), isNot(original));
  });

  test('payload actual con firma correcta coincide', () {
    const signature = 'firma-academica';

    final payload = jsonEncode({
      'type': 'academic_task',
      'user_id': 'A',
      'task_id': 'task-1',
      AcademicReminderScheduleIdentity.versionKey:
          AcademicReminderScheduleIdentity.version,
      AcademicReminderScheduleIdentity.signatureKey: signature,
    });

    expect(
      AcademicReminderScheduleIdentity.matches(
        payload: payload,
        expectedSignature: signature,
      ),
      isTrue,
    );

    expect(
      AcademicReminderScheduleIdentity.matches(
        payload: payload,
        expectedSignature: 'otra-firma',
      ),
      isFalse,
    );
  });

  test('payload heredado sin firma no se considera actualizado', () {
    final legacy = jsonEncode({
      'type': 'academic_task',
      'user_id': 'A',
      'task_id': 'task-1',
    });

    expect(
      AcademicReminderScheduleIdentity.matches(
        payload: legacy,
        expectedSignature: 'firma',
      ),
      isFalse,
    );
  });

  test('payload malformado o versión incompatible se rechaza', () {
    expect(
      AcademicReminderScheduleIdentity.matches(
        payload: '{invalido',
        expectedSignature: 'firma',
      ),
      isFalse,
    );

    final incompatible = jsonEncode({
      AcademicReminderScheduleIdentity.versionKey: 2,
      AcademicReminderScheduleIdentity.signatureKey: 'firma',
    });

    expect(
      AcademicReminderScheduleIdentity.matches(
        payload: incompatible,
        expectedSignature: 'firma',
      ),
      isFalse,
    );
  });
}
