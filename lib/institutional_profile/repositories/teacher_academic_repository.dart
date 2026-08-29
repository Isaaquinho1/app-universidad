import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAcademicRepository {
  TeacherAcademicRepository({SupabaseClient? supabaseClient})
    : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  Future<List<TeacherAssignment>> getMyAssignments() async {
    final response = await _supabaseClient.rpc('get_my_teacher_assignments');

    if (response is! List) {
      throw const FormatException(
        'La respuesta de asignaciones docentes no es válida.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (row) =>
              TeacherAssignment.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<List<TeacherAssignment>> searchAssignmentsAsAdmin({
    String? query,
    String? academicPeriodId,
    bool includeInactive = false,
    int limit = 100,
  }) async {
    final normalizedQuery = query?.trim();

    final response = await _supabaseClient.rpc(
      'search_teacher_assignments_as_admin',
      params: {
        'p_query':
            normalizedQuery == null || normalizedQuery.isEmpty
                ? null
                : normalizedQuery,
        'p_academic_period_id': academicPeriodId,
        'p_include_inactive': includeInactive,
        'p_limit': limit,
      },
    );

    if (response is! List) {
      throw const FormatException(
        'La respuesta de asignaciones administrativas no es válida.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (row) =>
              TeacherAssignment.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<List<TeacherProfileSummary>> searchTeachersAsAdmin({
    String? query,
    int limit = 50,
  }) async {
    final normalizedQuery = query?.trim();

    final response = await _supabaseClient.rpc(
      'search_teachers_as_admin',
      params: {
        'p_query':
            normalizedQuery == null || normalizedQuery.isEmpty
                ? null
                : normalizedQuery,
        'p_limit': limit,
      },
    );

    if (response is! List) {
      throw const FormatException('La respuesta de docentes no es válida.');
    }

    return response
        .whereType<Map>()
        .map(
          (row) => TeacherProfileSummary.fromSupabase(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((teacher) => teacher.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<InstitutionalSubject>> searchSubjectsAsAdmin({
    String? query,
    bool includeInactive = false,
    int limit = 100,
  }) async {
    final normalizedQuery = query?.trim();

    final response = await _supabaseClient.rpc(
      'search_institutional_subjects_as_admin',
      params: {
        'p_query':
            normalizedQuery == null || normalizedQuery.isEmpty
                ? null
                : normalizedQuery,
        'p_include_inactive': includeInactive,
        'p_limit': limit,
      },
    );

    if (response is! List) {
      throw const FormatException(
        'La respuesta de materias institucionales no es válida.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (row) =>
              InstitutionalSubject.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .where((subject) => subject.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> createSubjectAsAdmin({
    required String name,
    String? code,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'La materia requiere un nombre.');
    }

    await _supabaseClient.rpc(
      'create_institutional_subject_as_admin',
      params: {'p_name': normalizedName, 'p_code': _normalizeOptional(code)},
    );
  }

  Future<void> setSubjectActiveAsAdmin({
    required String subjectId,
    required bool active,
  }) async {
    await _supabaseClient.rpc(
      'set_institutional_subject_active_as_admin',
      params: {'p_subject_id': subjectId, 'p_active': active},
    );
  }

  Future<void> createAssignmentAsAdmin({
    required String teacherId,
    required String subjectId,
    required String academicGroupId,
    String? academicPeriodId,
  }) async {
    await _supabaseClient.rpc(
      'create_teacher_assignment_as_admin',
      params: {
        'p_teacher_id': teacherId,
        'p_subject_id': subjectId,
        'p_academic_group_id': academicGroupId.trim(),
        'p_academic_period_id': academicPeriodId,
      },
    );
  }

  Future<void> setAssignmentActiveAsAdmin({
    required String assignmentId,
    required bool active,
  }) async {
    await _supabaseClient.rpc(
      'set_teacher_assignment_active_as_admin',
      params: {'p_assignment_id': assignmentId, 'p_active': active},
    );
  }

  Future<void> createSessionAsAdmin({
    required String assignmentId,
    required int weekday,
    required String startsAt,
    required String endsAt,
    String? building,
    String? room,
  }) async {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(
        weekday,
        'weekday',
        'El día debe estar entre 1 y 7.',
      );
    }

    await _supabaseClient.rpc(
      'create_teacher_assignment_session_as_admin',
      params: {
        'p_assignment_id': assignmentId,
        'p_weekday': weekday,
        'p_starts_at': startsAt,
        'p_ends_at': endsAt,
        'p_building': _normalizeOptional(building),
        'p_room': _normalizeOptional(room),
      },
    );
  }

  Future<void> deleteSessionAsAdmin({required String sessionId}) async {
    await _supabaseClient.rpc(
      'delete_teacher_assignment_session_as_admin',
      params: {'p_session_id': sessionId},
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
