enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get databaseValue => name;

  static TaskPriority fromDatabase(String? value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => TaskPriority.medium,
    );
  }
}
