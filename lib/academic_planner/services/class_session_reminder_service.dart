import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_notification_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_schedule_identity.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_verified_cancellation_service.dart';
import 'package:conecta_itt/app/services/local_notification_service.dart';

class ClassSessionReminderService {
  ClassSessionReminderService({
    required this.userId,
    this.coordinator,
    this.authRevision,
    LocalNotificationService? localNotificationService,
  }) : assert((coordinator == null) == (authRevision == null)),
       _localNotificationService =
           localNotificationService ?? LocalNotificationService.instance;

  final String userId;
  final AcademicReminderOperationCoordinator? coordinator;
  final int? authRevision;
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
  }) =>
      _synchronize(session: session, subject: subject, preserveMatching: false);

  Future<void> _synchronize({
    required ClassSession session,
    required AcademicSubject subject,
    required bool preserveMatching,
  }) {
    return _execute((lease) async {
      if (preserveMatching && _shouldSchedule(session)) {
        lease?.ensureCurrent();

        final pending =
            await _localNotificationService.pendingNotificationRequests();

        lease?.ensureCurrent();

        final id = AcademicReminderNotificationIdentity.forClassSession(
          userId: userId,
          sessionId: session.id,
        );

        final sameSlot = pending.where((request) => request.id == id).toList();

        final reminder = _calculateReminderTime(session);

        final signature = AcademicReminderScheduleIdentity.forClassSession(
          body: _buildBody(subject: subject, session: session),
          weekday: reminder.weekday,
          hour: reminder.hour,
          minute: reminder.minute,
        );

        if (sameSlot.length == 1 &&
            AcademicReminderVerifiedCancellationService.isMatchingSchedule(
              id: sameSlot.single.id,
              payload: sameSlot.single.payload,
              userId: userId,
              recordId: session.id,
              isTask: false,
              expectedSignature: signature,
            )) {
          lease?.ensureCurrent();
          return;
        }
      }

      // La validación debe preceder a toda cancelación,
      // incluso durante las ediciones explícitas.
      await AcademicReminderVerifiedCancellationService(
        localNotificationService: _localNotificationService,
      ).ensureSlotAvailable(
        userId: userId,
        recordId: session.id,
        isTask: false,
        ensureCurrent: lease?.ensureCurrent,
      );

      lease?.ensureCurrent();
      await _cancelDirect(session.id, lease);

      lease?.ensureCurrent();

      if (!_shouldSchedule(session)) {
        return;
      }

      final reminder = _calculateReminderTime(session);

      lease?.ensureCurrent();

      await AcademicReminderVerifiedCancellationService(
        localNotificationService: _localNotificationService,
      ).ensureSlotAvailable(
        userId: userId,
        recordId: session.id,
        isTask: false,
        ensureCurrent: lease?.ensureCurrent,
      );

      lease?.ensureCurrent();

      await _localNotificationService.scheduleWeeklyAcademicReminder(
        id: AcademicReminderNotificationIdentity.forClassSession(
          userId: userId,
          sessionId: session.id,
        ),
        title: 'Clase próxima',
        body: _buildBody(subject: subject, session: session),
        weekday: reminder.weekday,
        hour: reminder.hour,
        minute: reminder.minute,
        payload: {
          'type': 'class_session',
          'session_id': session.id,
          'subject_id': subject.id,
          'user_id': userId,
          AcademicReminderScheduleIdentity.versionKey:
              AcademicReminderScheduleIdentity.version,
          AcademicReminderScheduleIdentity
              .signatureKey: AcademicReminderScheduleIdentity.forClassSession(
            body: _buildBody(subject: subject, session: session),
            weekday: reminder.weekday,
            hour: reminder.hour,
            minute: reminder.minute,
          ),
        },
        ensureCurrent: lease?.ensureCurrent,
      );

      // El plugin pudo terminar después de un cambio de cuenta.
      // La reconciliación posterior atenderá cualquier alarma tardía.
      lease?.ensureCurrent();
    });
  }

  Future<void> cancel(String sessionId) {
    return _execute((lease) => _cancelDirect(sessionId, lease));
  }

  Future<void> _cancelDirect(
    String sessionId,
    AcademicReminderOperationLease? lease,
  ) async {
    lease?.ensureCurrent();

    await AcademicReminderVerifiedCancellationService(
      localNotificationService: _localNotificationService,
    ).cancelOwned(
      userId: userId,
      recordId: sessionId,
      isTask: false,
      ensureCurrent: lease?.ensureCurrent,
    );

    lease?.ensureCurrent();
  }

  Future<void> _execute(
    Future<void> Function(AcademicReminderOperationLease? lease) operation,
  ) async {
    final activeCoordinator = coordinator;

    if (activeCoordinator == null) {
      if (authRevision != null) {
        throw StateError('Falta el coordinador académico.');
      }
      await operation(null);
      return;
    }

    final revision = authRevision;
    if (revision == null) {
      throw StateError('Falta la revisión de autenticación.');
    }

    await activeCoordinator.run(
      userId: userId,
      revision: revision,
      operation: (lease) => operation(lease),
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

      await _synchronize(
        session: session,
        subject: subject,
        preserveMatching: true,
      );
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
