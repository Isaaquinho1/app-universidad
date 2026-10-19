import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicReminderNotificationIdentity', () {
    test('el identificador de sesión es determinista', () {
      final first = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'sesion-1',
      );

      final second = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'sesion-1',
      );

      expect(first, second);
    });

    test('cuentas distintas generan identificadores distintos', () {
      final accountA = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'sesion-1',
      );

      final accountB = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-B',
        sessionId: 'sesion-1',
      );

      expect(accountA, isNot(accountB));
    });

    test('A -> B -> A conserva el identificador de la cuenta A', () {
      final firstA = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'sesion-1',
      );

      final accountB = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-B',
        sessionId: 'sesion-1',
      );

      final secondA = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'sesion-1',
      );

      expect(firstA, secondA);
      expect(firstA, isNot(accountB));
    });

    test('tareas y sesiones utilizan rangos independientes', () {
      final session = AcademicReminderNotificationIdentity.forClassSession(
        userId: 'usuario-A',
        sessionId: 'registro-1',
      );

      final task = AcademicReminderNotificationIdentity.forTask(
        userId: 'usuario-A',
        taskId: 'registro-1',
      );

      expect(session, inInclusiveRange(0x10000000, 0x1FFFFFFF));
      expect(task, inInclusiveRange(1, 0x0FFFFFFF));
      expect(session, isNot(task));
    });

    test('rechaza identificadores vacíos', () {
      expect(
        () => AcademicReminderNotificationIdentity.forClassSession(
          userId: '',
          sessionId: 'sesion-1',
        ),
        throwsArgumentError,
      );

      expect(
        () => AcademicReminderNotificationIdentity.forTask(
          userId: 'usuario-A',
          taskId: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
