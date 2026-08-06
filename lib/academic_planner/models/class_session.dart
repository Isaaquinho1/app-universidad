class ClassSession {
  const ClassSession({
    required this.id,
    required this.subjectId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.building,
    this.room,
    this.reminderMinutes,
    this.isActive = true,
  }) : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
       assert(startMinutes >= 0 && startMinutes < 1440),
       assert(endMinutes > startMinutes && endMinutes <= 1440);

  final String id;
  final String subjectId;

  /// Uses DateTime weekday values: Monday = 1, Sunday = 7.
  final int weekday;

  /// Minutes elapsed since midnight.
  final int startMinutes;
  final int endMinutes;

  final String? building;
  final String? room;
  final int? reminderMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get durationMinutes => endMinutes - startMinutes;

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'subject_id': subjectId,
      'weekday': weekday,
      'start_minutes': startMinutes,
      'end_minutes': endMinutes,
      'building': building,
      'room': room,
      'reminder_minutes': reminderMinutes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClassSession.fromDatabase(Map<String, Object?> row) {
    return ClassSession(
      id: row['id']! as String,
      subjectId: row['subject_id']! as String,
      weekday: row['weekday']! as int,
      startMinutes: row['start_minutes']! as int,
      endMinutes: row['end_minutes']! as int,
      building: row['building'] as String?,
      room: row['room'] as String?,
      reminderMinutes: row['reminder_minutes'] as int?,
      isActive: (row['is_active']! as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
