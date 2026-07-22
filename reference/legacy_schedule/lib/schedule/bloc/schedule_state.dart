part of 'schedule_bloc.dart';

enum ScheduleStatus { initial, loading, failure, loaded }

@freezed
class FieldDiff with _$FieldDiff {
  const factory FieldDiff({
    /// Nombre del campo (por ejemplo, "Fechas", "Aulas", "Docentes", "Horario / número de clase")
    required String fieldName,

    /// Para campos que no son fechas, se puede conservar el valor anterior y nuevo como texto
    String? oldValue,
    String? newValue,

    /// Para el campo Fechas: diferencia detallada de fechas agregadas
    List<DateTime>? addedDates,

    /// Para el campo Fechas: diferencia detallada de fechas eliminadas
    List<DateTime>? removedDates,

    /// Y qué fechas permanecieron sin cambios (pueden mostrarse sin resaltado)
    List<DateTime>? unchangedDates,
  }) = _FieldDiff;
}

enum ChangeType { added, removed, modified }

@freezed
class ScheduleChange with _$ScheduleChange {
  const factory ScheduleChange({
    /// Tipo de cambio: agregado, eliminado o modificado
    required ChangeType type,

    /// Nombre предмета, служащее заголовком для данного diff‑блока
    required String subject,

    /// Lista de cambios por campo: para clases agregadas y eliminadas se incluyen todos los campos,
    /// para clases modificadas, solo los campos que cambiaron.
    required List<FieldDiff> fieldDiffs,
  }) = _ScheduleChange;
}

@freezed
class ScheduleDiff with _$ScheduleDiff {
  const factory ScheduleDiff({
    /// Conjunto de cambios en el horario (puede convertirse en lista para facilitar su visualización)
    required Set<ScheduleChange> changes,
  }) = _ScheduleDiff;
}

@freezed
class ScheduleState with _$ScheduleState {
  const factory ScheduleState({
    @Default(ScheduleStatus.initial) @JsonKey(includeFromJson: false, includeToJson: false) ScheduleStatus status,
    @Default([]) List<(UID, Classroom, List<SchedulePart>)> classroomsSchedule,
    @Default([]) List<(UID, Teacher, List<SchedulePart>)> teachersSchedule,
    @Default([]) List<(UID, Group, List<SchedulePart>)> groupsSchedule,
    @Default(false) bool isMiniature,
    @Default([]) List<LessonComment> comments,
    @Default([]) List<LessonReactionSummary> reactionSummaries,
    @Default(false) bool showEmptyLessons,
    @Default(true) bool showCommentsIndicators,
    @Default(false) bool isListModeEnabled,
    @Default([]) List<ScheduleComment> scheduleComments,
    @SelectedScheduleConverter() SelectedSchedule? selectedSchedule,
    @Default({}) @JsonKey(includeFromJson: false, includeToJson: false) Set<SelectedSchedule> comparisonSchedules,
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false) bool isComparisonModeEnabled,
    @Default(null) @JsonKey(includeFromJson: false, includeToJson: false) ScheduleDiff? latestDiff,
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false) bool showScheduleDiffDialog,

    // Desktop mode state properties
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false) bool isSplitViewEnabled,
    @Default(true) @JsonKey(includeFromJson: false, includeToJson: false) bool showAnalytics,

    // Custom schedules
    @Default([]) List<CustomSchedule> customSchedules,
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false) bool isCustomScheduleModeEnabled,
  }) = _ScheduleState;

  const ScheduleState._();

  factory ScheduleState.fromJson(Map<String, dynamic> json) => _$ScheduleStateFromJson(json);
}

class SelectedScheduleConverter implements JsonConverter<SelectedSchedule?, Map<String, dynamic>?> {
  const SelectedScheduleConverter();

  @override
  Map<String, dynamic>? toJson(SelectedSchedule? selectedSchedule) => selectedSchedule?.toJson();

  @override
  SelectedSchedule? fromJson(Object? jsonString) =>
      jsonString != null ? SelectedSchedule.fromJson(jsonString as Map<String, dynamic>) : null;
}
