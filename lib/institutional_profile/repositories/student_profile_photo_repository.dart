import 'dart:typed_data';

import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_library;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum StudentProfilePhotoSource { camera, gallery }

/// Manages private institutional photographs used by the digital student ID.
class StudentProfilePhotoRepository {
  StudentProfilePhotoRepository({
    required SupabaseClient supabaseClient,
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
  }) : _supabaseClient = supabaseClient,
       _imagePicker = imagePicker ?? ImagePicker(),
       _imageCropper = imageCropper ?? ImageCropper();

  final SupabaseClient _supabaseClient;
  final ImagePicker _imagePicker;
  final ImageCropper _imageCropper;

  static const bucketName = 'student-profile-photos';
  static const maxFileSizeBytes = 5 * 1024 * 1024;

  static const outputWidth = 1200;
  static const outputHeight = 1500;
  static const outputJpegQuality = 88;

  /// Selects, crops and normalizes one institutional photograph.
  ///
  /// Every successful result is a portrait JPEG in 4:5 proportion with
  /// dimensions no greater than 1200 x 1500 pixels.
  Future<PlatformFile?> pickAndPreparePhoto({
    required StudentProfilePhotoSource source,
  }) async {
    final pickedFile = await _imagePicker.pickImage(
      source:
          source == StudentProfilePhotoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: false,
    );

    if (pickedFile == null) {
      return null;
    }

    final croppedFile = await _imageCropper.cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar fotografía',
          toolbarColor: const Color(0xFF003B5C),
          toolbarWidgetColor: Colors.white,
          statusBarLight: false,
          activeControlsWidgetColor: const Color(0xFF003B5C),
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar fotografía',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          doneButtonTitle: 'Usar',
          cancelButtonTitle: 'Cancelar',
        ),
      ],
    );

    if (croppedFile == null) {
      return null;
    }

    final inputBytes = await croppedFile.readAsBytes();

    if (inputBytes.isEmpty) {
      throw const FormatException(
        'No se pudieron leer los datos de la fotografía recortada.',
      );
    }

    final decoded = image_library.decodeImage(inputBytes);

    if (decoded == null) {
      throw const FormatException(
        'La fotografía seleccionada no pudo procesarse.',
      );
    }

    final oriented = image_library.bakeOrientation(decoded);
    final normalized = _resizeToCredentialBounds(oriented);

    final outputBytes = Uint8List.fromList(
      image_library.encodeJpg(normalized, quality: outputJpegQuality),
    );

    final result = PlatformFile(
      name: 'profile_photo.jpg',
      size: outputBytes.length,
      bytes: outputBytes,
    );

    _validateFile(result);

    return result;
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
    final nextPath = '$uid/${const Uuid().v4()}.jpg';

    await _supabaseClient.storage
        .from(bucketName)
        .uploadBinary(
          nextPath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
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
          // The new photograph is already authoritative.
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
        // The profile no longer references this object.
      }
    }

    return updatedProfile;
  }

  image_library.Image _resizeToCredentialBounds(image_library.Image source) {
    if (source.width <= outputWidth && source.height <= outputHeight) {
      return source;
    }

    final widthScale = outputWidth / source.width;
    final heightScale = outputHeight / source.height;
    final scale = widthScale < heightScale ? widthScale : heightScale;

    final targetWidth = (source.width * scale).round();
    final targetHeight = (source.height * scale).round();

    return image_library.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: image_library.Interpolation.average,
    );
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

    if (!name.toLowerCase().endsWith('.jpg') &&
        !name.toLowerCase().endsWith('.jpeg')) {
      throw const FormatException(
        'La fotografía normalizada debe estar en formato JPEG.',
      );
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
}
