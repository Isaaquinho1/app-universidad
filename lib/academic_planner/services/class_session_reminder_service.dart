import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';

class ClassSessionReminderService {
  ClassSessionReminderService({
    LocalNotificationService? localNotificationService,
  }) : _localNotificationService =
           localNotificationService ?? LocalNotificationService.instance;

  final LocalNotificationService _localNotificationService;

  Future<bool> requestPermission() {
    return _localNotificationService.requestNotificationPermission();
  }

  Future<bool> requestExactAlarmPermission() {
    return _localNotificationService.requestExactAlarmPermission();
  }

  Future<void> synchronize({
    required ClassSession session,
    required AcademicSubject subject,
  }) async {
    await cancel(session.id);

    if (!_shouldSchedule(session)) {
      return;
    }

    final reminder = _calculateReminderTime(session);

    await _localNotificationService.scheduleWeeklyAcademicReminder(
      id: notificationIdForSession(session.id),
      title: 'Clase próxima',
      body: _buildBody(subject: subject, session: session),
      weekday: reminder.weekday,
      hour: reminder.hour,
      minute: reminder.minute,
      payload: {
        'type': 'class_session',
        'session_id': session.id,
        'subject_id': subject.id,
      },
    );
  }

  Future<void> cancel(String sessionId) {
    return _localNotificationService.cancelNotification(
      notificationIdForSession(sessionId),
    );
  }

  Future<void> restore({
    required Iterable<ClassSession> sessions,
    required Map<String, AcademicSubject> subjectsById,
  }) async {
    for (final session in sessions) {
      final subject = subjectsById[session.subjectId];

      if (subject == null) {
        continue;
      }

      await synchronize(session: session, subject: subject);
    }
  }

  bool _shouldSchedule(ClassSession session) {
    return session.isActive && session.reminderMinutes != null;
  }

  _WeeklyReminderTime _calculateReminderTime(ClassSession session) {
    final reminderMinutes = session.reminderMinutes ?? 0;

    final totalMinutes = session.startMinutes - reminderMinutes;

    var weekday = session.weekday;
    var normalizedMinutes = totalMinutes;

    while (normalizedMinutes < 0) {
      normalizedMinutes += 1440;
      weekday--;

      if (weekday < DateTime.monday) {
        weekday = DateTime.sunday;
      }
    }

    while (normalizedMinutes >= 1440) {
      normalizedMinutes -= 1440;
      weekday++;

      if (weekday > DateTime.sunday) {
        weekday = DateTime.monday;
      }
    }

    return _WeeklyReminderTime(
      weekday: weekday,
      hour: normalizedMinutes ~/ 60,
      minute: normalizedMinutes % 60,
    );
  }

  String _buildBody({
    required AcademicSubject subject,
    required ClassSession session,
  }) {
    final location = [
      session.building,
      session.room,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    if (location.isEmpty) {
      return subject.name;
    }

    return '${subject.name} · $location';
  }

  int notificationIdForSession(String sessionId) {
    const offsetBasis = 0x811C9DC5;
    const prime = 0x01000193;

    var hash = offsetBasis;

    for (final codeUnit in sessionId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }

    // Rango independiente al usado por AcademicTaskReminderService.
    return 0x20000000 | (hash & 0x1FFFFFFF);
  }
}

class _WeeklyReminderTime {
  const _WeeklyReminderTime({
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int weekday;
  final int hour;
  final int minute;
}
