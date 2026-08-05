import 'dart:async';

import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository that manages institutional profiles in Supabase.
class AppUserProfileRepository {
  /// Creates an [AppUserProfileRepository].
  const AppUserProfileRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const _profilesTable = 'profiles';

  /// Watches the institutional profile for the provided [uid].
  ///
  /// The initial profile is emitted immediately. Further database updates
  /// require Realtime to be enabled for the `profiles` table.
  Stream<AppUserProfile?> watchProfile(String uid) {
    if (uid.isEmpty) {
      return Stream.value(null);
    }

    return _supabaseClient
        .from(_profilesTable)
        .stream(primaryKey: const ['id'])
        .eq('id', uid)
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }

          return AppUserProfile.fromSupabase(rows.first);
        });
  }

  /// Fetches the institutional profile for the provided [uid].
  Future<AppUserProfile?> fetchProfile(String uid) async {
    if (uid.isEmpty) {
      return null;
    }

    final row =
        await _supabaseClient
            .from(_profilesTable)
            .select()
            .eq('id', uid)
            .maybeSingle();

    if (row == null) {
      return null;
    }

    return AppUserProfile.fromSupabase(row);
  }

  /// Returns the profile created by the `auth.users` database trigger.
  ///
  /// Profile creation is intentionally performed by the database. Flutter
  /// must not insert profiles directly because role and account classification
  /// are protected server-side.
  Future<AppUserProfile> ensureStudentProfile({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID cannot be empty.');
    }

    final authenticatedUser = _supabaseClient.auth.currentUser;

    if (authenticatedUser == null || authenticatedUser.id != uid) {
      throw StateError(
        'The authenticated Supabase user does not match the requested profile.',
      );
    }

    // The auth trigger is synchronous, but a short retry also protects the app
    // against transient network or replication delays.
    for (var attempt = 0; attempt < 4; attempt++) {
      final profile = await fetchProfile(uid);

      if (profile != null) {
        return profile;
      }

      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }

    throw StateError(
      'No institutional profile exists for the authenticated user.',
    );
  }

  /// Updates academic fields through the protected database function.
  Future<AppUserProfile> updateProfile({
    required String uid,
    String? displayName,
    String? careerId,
    int? semester,
    String? groupId,
    String? controlNumber,
    bool? profileCompleted,
  }) async {
    _validateCurrentUser(uid);

    if (displayName != null) {
      throw UnsupportedError(
        'The institutional display name is defined during registration '
        'and cannot be updated from the client.',
      );
    }

    if (controlNumber != null) {
      throw UnsupportedError(
        'The control number is generated from the institutional email '
        'and cannot be updated from the client.',
      );
    }

    final response = await _supabaseClient.rpc(
      'update_own_profile',
      params: {
        'p_display_name': null,
        'p_career_id': careerId,
        'p_semester': semester,
        'p_group_id': groupId,
        'p_profile_completed': profileCompleted,
      },
    );

    if (response is! Map) {
      throw StateError(
        'The profile update did not return the updated institutional profile.',
      );
    }

    return AppUserProfile.fromSupabase(Map<String, dynamic>.from(response));
  }

  /// Updates the role of a user.
  ///
  /// Roles cannot be changed directly from the mobile client. A dedicated
  /// superAdmin RPC or trusted backend flow will be implemented later.
  Future<void> updateRole({
    required String uid,
    required AppUserRole role,
  }) async {
    throw UnsupportedError(
      'Institutional roles must be changed through a trusted admin flow.',
    );
  }

  /// Registers or transfers an FCM token to the active account.
  ///
  /// The token identifies the app installation. If another user signs in
  /// on the same device, Supabase atomically transfers the token so that
  /// notifications are delivered only to the current account.
  Future<void> updateFcmToken({
    required String uid,
    required String deviceId,
    required String token,
    required String platform,
  }) async {
    _validateCurrentUser(uid);

    final normalizedDeviceId = deviceId.trim();
    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim().toLowerCase();

    if (normalizedDeviceId.isEmpty) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'Device ID cannot be empty.',
      );
    }

    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'FCM token cannot be empty.');
    }

    const supportedPlatforms = {'android', 'ios'};

    if (!supportedPlatforms.contains(normalizedPlatform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'Unsupported notification platform.',
      );
    }

    await _supabaseClient.rpc(
      'register_current_user_fcm_token',
      params: {
        'p_device_id': normalizedDeviceId,
        'p_token': normalizedToken,
        'p_platform': normalizedPlatform,
      },
    );
  }

  void _validateCurrentUser(String uid) {
    final authenticatedUser = _supabaseClient.auth.currentUser;

    if (authenticatedUser == null) {
      throw StateError('An authenticated Supabase user is required.');
    }

    if (authenticatedUser.id != uid) {
      throw StateError('The authenticated user cannot modify another profile.');
    }
  }
}
