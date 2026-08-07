import 'package:conecta_itt/academic_planner/database/academic_database.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';

class DailyScheduleRepository {
  DailyScheduleRepository({AcademicDatabase? academicDatabase})
    : _academicDatabase = academicDatabase ?? AcademicDatabase.instance;

  final AcademicDatabase _academicDatabase;

  Future<List<ScheduledClass>> getByWeekday(int weekday) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday');
    }

    final database = await _academicDatabase.database;

    final rows = await database.rawQuery(
      '''
      SELECT
        s.id AS session_id,
        s.subject_id,
        s.weekday,
        s.start_minutes,
        s.end_minutes,
        s.building,
        s.room,
        s.reminder_minutes,
        s.is_active,
        s.created_at AS session_created_at,
        s.updated_at AS session_updated_at,
        a.id AS academic_subject_id,
        a.name,
        a.code,
        a.teacher_name,
        a.color_value,
        a.notes,
        a.is_archived,
        a.created_at AS subject_created_at,
        a.updated_at AS subject_updated_at
      FROM class_sessions s
      INNER JOIN academic_subjects a
        ON a.id = s.subject_id
      WHERE
        s.weekday = ?
        AND s.is_active = 1
        AND a.is_archived = 0
      ORDER BY s.start_minutes ASC
      ''',
      [weekday],
    );

    return rows
        .map((row) {
          final subject = AcademicSubject(
            id: row['academic_subject_id']! as String,
            name: row['name']! as String,
            code: row['code'] as String?,
            teacherName: row['teacher_name'] as String?,
            colorValue: row['color_value']! as int,
            notes: row['notes'] as String?,
            isArchived: (row['is_archived']! as int) == 1,
            createdAt: DateTime.parse(row['subject_created_at']! as String),
            updatedAt: DateTime.parse(row['subject_updated_at']! as String),
          );

          final session = ClassSession(
            id: row['session_id']! as String,
            subjectId: row['subject_id']! as String,
            weekday: row['weekday']! as int,
            startMinutes: row['start_minutes']! as int,
            endMinutes: row['end_minutes']! as int,
            building: row['building'] as String?,
            room: row['room'] as String?,
            reminderMinutes: row['reminder_minutes'] as int?,
            isActive: (row['is_active']! as int) == 1,
            createdAt: DateTime.parse(row['session_created_at']! as String),
            updatedAt: DateTime.parse(row['session_updated_at']! as String),
          );

          return ScheduledClass(subject: subject, session: session);
        })
        .toList(growable: false);
  }
}
