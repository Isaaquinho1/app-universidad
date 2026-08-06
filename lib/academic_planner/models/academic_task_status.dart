enum AcademicTaskStatus {
  pending,
  inProgress,
  completed,
  archived;

  String get databaseValue => name;

  static AcademicTaskStatus fromDatabase(String? value) {
    return AcademicTaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AcademicTaskStatus.pending,
    );
  }
}
