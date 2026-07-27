import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the academic catalog required during institutional registration.
class AcademicCatalogRepository {
  const AcademicCatalogRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  Future<List<AcademicGroup>> fetchGroups({
    required String careerId,
    required int semester,
  }) async {
    final normalizedCareerId = careerId.trim().toLowerCase();

    if (normalizedCareerId.isEmpty || semester < 1 || semester > 14) {
      return const [];
    }

    final response = await _supabaseClient.rpc(
      'get_registration_academic_groups',
      params: {'p_career_id': normalizedCareerId, 'p_semester': semester},
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => AcademicGroup.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .where((group) => group.id.isNotEmpty)
        .toList(growable: false);
  }
}
