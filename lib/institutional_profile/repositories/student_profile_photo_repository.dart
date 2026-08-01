import 'dart:typed_data';

import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Manages private institutional photographs used by the digital student ID.
class StudentProfilePhotoRepository {
  const StudentProfilePhotoRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const bucketName = 'student-profile-photos';
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  static const allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  /// Selects one photograph from the device.
  Future<PlatformFile?> pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions.toList(growable: false),
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    _validateFile(file);

    return file;
  }

  /// Uploads a new photograph and registers it as pending review.
  ///
  /// The previous photograph is removed only after the new upload and profile
  /// update succeed, so a failed replacement never leaves the profile empty.
  Future<AppUserProfile> submitPhoto({
    required String uid,
    required PlatformFile file,
    String? previousPhotoPath,
  }) async {
    _validateCurrentUser(uid);
    _validateFile(file);

    final bytes = _requireBytes(file);
    final extension = _extensionOf(file.name);
    final mimeType = _mimeTypeForExtension(extension);
    final nextPath = '$uid/${const Uuid().v4()}.$extension';

    await _supabaseClient.storage
        .from(bucketName)
        .uploadBinary(
          nextPath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      final response = await _supabaseClient.rpc(
        'submit_own_profile_photo',
        params: {'p_photo_path': nextPath},
      );

      if (response is! Map) {
        throw StateError(
          'The photograph submission did not return the updated profile.',
        );
      }

      final updatedProfile = AppUserProfile.fromSupabase(
        Map<String, dynamic>.from(response),
      );

      final previousPath = previousPhotoPath?.trim();

      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != nextPath) {
        try {
          await _supabaseClient.storage.from(bucketName).remove([previousPath]);
        } catch (_) {
          // The new photograph is already authoritative. A stale object can
          // be removed later without affecting the current profile.
        }
      }

      return updatedProfile;
    } catch (_) {
      try {
        await _supabaseClient.storage.from(bucketName).remove([nextPath]);
      } catch (_) {
        // Preserve the original submission error.
      }

      rethrow;
    }
  }

  /// Creates a temporary URL for the private photograph.
  Future<String> createSignedUrl(
    String photoPath, {
    int expiresInSeconds = 3600,
  }) async {
    final normalizedPath = photoPath.trim();

    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(
        photoPath,
        'photoPath',
        'A non-empty profile photograph path is required.',
      );
    }

    if (expiresInSeconds < 60 || expiresInSeconds > 86400) {
      throw ArgumentError.value(
        expiresInSeconds,
        'expiresInSeconds',
        'Signed URLs must last between 60 seconds and 24 hours.',
      );
    }

    return _supabaseClient.storage
        .from(bucketName)
        .createSignedUrl(normalizedPath, expiresInSeconds);
  }

  /// Removes the current photograph from the profile and Storage.
  Future<AppUserProfile> removePhoto({
    required String uid,
    required String photoPath,
  }) async {
    _validateCurrentUser(uid);

    final normalizedPath = photoPath.trim();

    final response = await _supabaseClient.rpc('remove_own_profile_photo');

    if (response is! Map) {
      throw StateError(
        'The photograph removal did not return the updated profile.',
      );
    }

    final updatedProfile = AppUserProfile.fromSupabase(
      Map<String, dynamic>.from(response),
    );

    if (normalizedPath.isNotEmpty) {
      try {
        await _supabaseClient.storage.from(bucketName).remove([normalizedPath]);
      } catch (_) {
        // The profile no longer references this object. A stale Storage object
        // can be cleaned later without affecting the account.
      }
    }

    return updatedProfile;
  }

  void _validateCurrentUser(String uid) {
    final user = _supabaseClient.auth.currentUser;

    if (user == null) {
      throw StateError('An authenticated Supabase user is required.');
    }

    if (user.id != uid) {
      throw StateError(
        'The authenticated user cannot modify another profile photograph.',
      );
    }
  }

  void _validateFile(PlatformFile file) {
    final name = file.name.trim();

    if (name.isEmpty) {
      throw const FormatException(
        'La fotografía seleccionada no tiene un nombre válido.',
      );
    }

    if (file.size <= 0) {
      throw const FormatException('La fotografía seleccionada está vacía.');
    }

    if (file.size > maxFileSizeBytes) {
      throw const FormatException(
        'La fotografía supera el límite permitido de 5 MiB.',
      );
    }

    final extension = _extensionOf(name);

    if (!allowedExtensions.contains(extension)) {
      throw FormatException('El formato .$extension no está permitido.');
    }

    _requireBytes(file);
  }

  Uint8List _requireBytes(PlatformFile file) {
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'No se pudieron leer los datos de la fotografía.',
      );
    }

    return bytes;
  }

  String _extensionOf(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final separator = normalized.lastIndexOf('.');

    if (separator < 0 || separator == normalized.length - 1) {
      throw const FormatException(
        'La fotografía no tiene una extensión válida.',
      );
    }

    return normalized.substring(separator + 1);
  }

  String _mimeTypeForExtension(String extension) {
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ =>
        throw FormatException(
          'No existe un tipo MIME permitido para .$extension.',
        ),
    };
  }
}
