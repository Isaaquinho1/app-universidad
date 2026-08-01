import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supported administrative filters for institutional photographs.
enum ProfilePhotoReviewFilter {
  pending,
  approved,
  rejected,
  all;

  String get value => name;
}

/// Secure administrative access to institutional photograph reviews.
class AdminProfilePhotoRepository {
  const AdminProfilePhotoRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  /// Returns photograph submissions visible to administrators.
  Future<List<AppUserProfile>> fetchReviewQueue({
    ProfilePhotoReviewFilter filter = ProfilePhotoReviewFilter.pending,
  }) async {
    final response = await _supabaseClient.rpc(
      'get_profile_photo_review_queue',
      params: {'p_status': filter.value},
    );

    if (response is! List) {
      throw StateError(
        'The photograph review queue returned an invalid response.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (row) => AppUserProfile.fromSupabase(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  /// Approves one pending institutional photograph.
  Future<AppUserProfile> approvePhoto({required String profileId}) {
    return _reviewPhoto(profileId: profileId, decision: 'approved');
  }

  /// Rejects one pending institutional photograph.
  Future<AppUserProfile> rejectPhoto({
    required String profileId,
    required String reason,
  }) {
    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw const FormatException('Debes indicar el motivo del rechazo.');
    }

    if (normalizedReason.length > 500) {
      throw const FormatException(
        'El motivo del rechazo no puede superar 500 caracteres.',
      );
    }

    return _reviewPhoto(
      profileId: profileId,
      decision: 'rejected',
      rejectionReason: normalizedReason,
    );
  }

  Future<AppUserProfile> _reviewPhoto({
    required String profileId,
    required String decision,
    String? rejectionReason,
  }) async {
    final normalizedId = profileId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'A profile identifier is required.',
      );
    }

    final response = await _supabaseClient.rpc(
      'review_profile_photo',
      params: {
        'p_profile_id': normalizedId,
        'p_decision': decision,
        'p_rejection_reason': rejectionReason,
      },
    );

    if (response is! Map) {
      throw StateError(
        'The photograph review did not return the updated profile.',
      );
    }

    return AppUserProfile.fromSupabase(Map<String, dynamic>.from(response));
  }
}
