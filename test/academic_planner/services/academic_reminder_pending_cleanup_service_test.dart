import 'dart:convert';

import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const activeUser = 'student-B';
  const otherUser = 'student-A';

  int taskId(String userId, String id) =>
      AcademicReminderNotificationIdentity.forTask(userId: userId, taskId: id);

  int sessionId(String userId, String id) =>
      AcademicReminderNotificationIdentity.forClassSession(
        userId: userId,
        sessionId: id,
      );

  int legacyId(String id, {required bool task}) {
    const offsetBasis = 0x811C9DC5;
    const prime = 0x01000193;
    var hash = offsetBasis;

    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }

    return task
        ? 0x40000000 | (hash & 0x3FFFFFFF)
        : 0x20000000 | (hash & 0x1FFFFFFF);
  }

  String taskPayload(String owner, String id) =>
      jsonEncode({'type': 'academic_task', 'task_id': id, 'user_id': owner});

  String sessionPayload(String owner, String id) => jsonEncode({
    'type': 'class_session',
    'session_id': id,
    'subject_id': 'subject-1',
    'user_id': owner,
  });

  bool remove(int id, String? payload, {String user = activeUser}) =>
      AcademicReminderPendingCleanupService.shouldCancel(
        id: id,
        payload: payload,
        activeUserId: user,
      );

  group('Limpieza de recordatorios por identidad', () {
    test('conserva tarea de la cuenta activa', () {
      expect(
        remove(taskId(activeUser, 't1'), taskPayload(activeUser, 't1')),
        isFalse,
      );
    });

    test('identifica tarea de otra cuenta', () {
      expect(
        remove(taskId(otherUser, 't1'), taskPayload(otherUser, 't1')),
        isTrue,
      );
    });

    test('conserva clase de la cuenta activa', () {
      expect(
        remove(sessionId(activeUser, 's1'), sessionPayload(activeUser, 's1')),
        isFalse,
      );
    });

    test('identifica clase de otra cuenta', () {
      expect(
        remove(sessionId(otherUser, 's1'), sessionPayload(otherUser, 's1')),
        isTrue,
      );
    });

    test('conserva tarea y clase heredadas sin propietario', () {
      expect(
        remove(
          legacyId('t1', task: true),
          '{"type":"academic_task","task_id":"t1"}',
        ),
        isFalse,
      );

      expect(
        remove(
          legacyId('s1', task: false),
          '{"type":"class_session","session_id":"s1",'
          '"subject_id":"subject-1"}',
        ),
        isFalse,
      );
    });

    test('rechaza rango correcto con hash incorrecto', () {
      final correct = taskId(otherUser, 't1');
      final wrong = correct == 1 ? 2 : correct - 1;

      expect(remove(wrong, taskPayload(otherUser, 't1')), isFalse);
    });

    test('rechaza propietario que no corresponde al ID', () {
      expect(
        remove(taskId(activeUser, 't1'), taskPayload(otherUser, 't1')),
        isFalse,
      );
    });

    test('rechaza ID heredado que no corresponde al registro', () {
      expect(
        remove(
          legacyId('t1', task: true),
          '{"type":"academic_task","task_id":"otra-tarea"}',
        ),
        isFalse,
      );
    });

    test('conserva comunicados institucionales', () {
      expect(
        remove(
          taskId(otherUser, 't1'),
          '{"type":"announcement","announcement_id":"a1"}',
        ),
        isFalse,
      );

      expect(
        remove(legacyId('t1', task: true), '{"announcement_id":"a1"}'),
        isFalse,
      );
    });

    test('rechaza payloads incompletos y cuenta vacía', () {
      expect(remove(123, null), isFalse);
      expect(remove(123, '{error'), isFalse);
      expect(remove(123, '[]'), isFalse);

      expect(
        remove(
          taskId(otherUser, 't1'),
          '{"type":"academic_task","task_id":"t1"}',
        ),
        isFalse,
      );

      expect(
        remove(taskId(otherUser, 't1'), taskPayload(otherUser, 't1'), user: ''),
        isFalse,
      );
    });
  });
}
