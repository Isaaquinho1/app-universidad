class TeacherAssignmentSession {
  const TeacherAssignmentSession({
    required this.id,
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
    this.building,
    this.room,
  });

  factory TeacherAssignmentSession.fromSupabase(Map<String, dynamic> row) {
    return TeacherAssignmentSession(
      id: row['id'] as String,
      weekday: (row['weekday'] as num).toInt(),
      startsAt: row['starts_at'] as String,
      endsAt: row['ends_at'] as String,
      building: row['building'] as String?,
      room: row['room'] as String?,
    );
  }

  final String id;
  final int weekday;
  final String startsAt;
  final String endsAt;
  final String? building;
  final String? room;

  String get weekdayLabel {
    return switch (weekday) {
      1 => 'Lunes',
      2 => 'Martes',
      3 => 'Miércoles',
      4 => 'Jueves',
      5 => 'Viernes',
      6 => 'Sábado',
      7 => 'Domingo',
      _ => 'Día $weekday',
    };
  }

  String get timeLabel {
    return '${_shortTime(startsAt)} – ${_shortTime(endsAt)}';
  }

  String? get locationLabel {
    final parts = <String>[
      if (building?.trim().isNotEmpty ?? false) building!.trim(),
      if (room?.trim().isNotEmpty ?? false) room!.trim(),
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' · ');
  }

  static String _shortTime(String value) {
    final normalized = value.trim();

    if (normalized.length >= 5) {
      return normalized.substring(0, 5);
    }

    return normalized;
  }
}
