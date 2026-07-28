import 'dart:typed_data';

import 'package:conecta_itt/announcements/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Manages private media and document assets for institutional publications.
///
/// Storage objects live in the private `institutional-publications` bucket.
/// Their authoritative metadata lives in `public.publication_assets`.
class PublicationAssetRepository {
  const PublicationAssetRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const bucketName = PublicationAsset.defaultBucket;
  static const _assetsTable = 'publication_assets';

  static const maxFileSizeBytes = 25 * 1024 * 1024;

  static const allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
  };

  /// Selects one cover image from the device.
  Future<PlatformFile?> pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'heic',
        'heif',
      ],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single;
  }

  /// Selects one or more gallery images.
  Future<List<PlatformFile>> pickGalleryImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'heic',
        'heif',
      ],
      allowMultiple: true,
      withData: true,
    );

    return result?.files ?? const [];
  }

  /// Selects one or more supported institutional documents.
  Future<List<PlatformFile>> pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
      ],
      allowMultiple: true,
      withData: true,
    );

    return result?.files ?? const [];
  }

  /// Returns all managed assets for one publication.
  Future<List<PublicationAsset>> fetchAssets({
    required String publicationId,
  }) async {
    _validatePublicationId(publicationId);

    final rows = await _supabaseClient
        .from(_assetsTable)
        .select()
        .eq('publication_id', publicationId)
        .order('display_order')
        .order('created_at');

    return rows.map(PublicationAsset.fromSupabase).toList(growable: false);
  }

  /// Returns the cover asset for one publication, when available.
  Future<PublicationAsset?> fetchCover({required String publicationId}) async {
    _validatePublicationId(publicationId);

    final row =
        await _supabaseClient
            .from(_assetsTable)
            .select()
            .eq('publication_id', publicationId)
            .eq('asset_type', PublicationAssetType.cover.value)
            .maybeSingle();

    if (row == null) {
      return null;
    }

    return PublicationAsset.fromSupabase(row);
  }

  /// Uploads and registers one managed publication asset.
  ///
  /// If metadata registration fails, the Storage object is removed so that
  /// the upload does not remain orphaned.
  Future<PublicationAsset> uploadAsset({
    required String publicationId,
    required PlatformFile file,
    required PublicationAssetType type,
    int displayOrder = 0,
  }) async {
    _validatePublicationId(publicationId);
    _validateFile(file: file, type: type);

    final user = _supabaseClient.auth.currentUser;

    if (user == null) {
      throw StateError(
        'An authenticated administrator is required to upload assets.',
      );
    }

    final bytes = _requireBytes(file);
    final extension = _extensionOf(file.name);
    final mimeType = _mimeTypeForExtension(extension);
    final storagePath = _buildStoragePath(
      publicationId: publicationId,
      type: type,
      extension: extension,
    );

    await _supabaseClient.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
            upsert: false,
          ),
        );

    try {
      final row =
          await _supabaseClient
              .from(_assetsTable)
              .insert({
                'publication_id': publicationId,
                'asset_type': type.value,
                'storage_bucket': bucketName,
                'storage_path': storagePath,
                'original_name': file.name.trim(),
                'mime_type': mimeType,
                'size_bytes': file.size,
                'display_order': displayOrder,
                'uploaded_by': user.id,
              })
              .select()
              .single();

      return PublicationAsset.fromSupabase(row);
    } catch (_) {
      try {
        await _supabaseClient.storage.from(bucketName).remove([storagePath]);
      } catch (_) {
        // Preserve the original metadata registration error.
      }

      rethrow;
    }
  }

  /// Replaces the current cover image.
  ///
  /// The new cover is uploaded first. The former cover is removed only after
  /// the new asset has been registered successfully.
  Future<PublicationAsset> replaceCover({
    required String publicationId,
    required PlatformFile file,
  }) async {
    final currentCover = await fetchCover(publicationId: publicationId);

    if (currentCover != null) {
      await deleteAsset(currentCover);
    }

    return uploadAsset(
      publicationId: publicationId,
      file: file,
      type: PublicationAssetType.cover,
    );
  }

  /// Creates a temporary URL for a private publication asset.
  Future<String> createSignedUrl(
    PublicationAsset asset, {
    int expiresInSeconds = 3600,
  }) async {
    if (asset.storagePath.trim().isEmpty) {
      throw ArgumentError.value(
        asset.storagePath,
        'asset.storagePath',
        'A non-empty Storage path is required.',
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
        .from(asset.storageBucket)
        .createSignedUrl(asset.storagePath, expiresInSeconds);
  }

  /// Deletes one Storage object and its metadata.
  Future<void> deleteAsset(PublicationAsset asset) async {
    if (asset.id.trim().isEmpty) {
      throw ArgumentError.value(
        asset.id,
        'asset.id',
        'An asset identifier is required.',
      );
    }

    if (asset.storagePath.trim().isEmpty) {
      throw ArgumentError.value(
        asset.storagePath,
        'asset.storagePath',
        'A Storage path is required.',
      );
    }

    await _supabaseClient.storage.from(asset.storageBucket).remove([
      asset.storagePath,
    ]);

    await _supabaseClient.from(_assetsTable).delete().eq('id', asset.id);
  }

  /// Deletes all assets related to one publication.
  Future<void> deleteAllAssets({required String publicationId}) async {
    final assets = await fetchAssets(publicationId: publicationId);

    for (final asset in assets) {
      await deleteAsset(asset);
    }
  }

  void _validateFile({
    required PlatformFile file,
    required PublicationAssetType type,
  }) {
    final name = file.name.trim();

    if (name.isEmpty) {
      throw const FormatException(
        'El archivo seleccionado no tiene un nombre válido.',
      );
    }

    if (file.size <= 0) {
      throw const FormatException('El archivo seleccionado está vacío.');
    }

    if (file.size > maxFileSizeBytes) {
      throw const FormatException(
        'El archivo supera el límite permitido de 25 MiB.',
      );
    }

    final extension = _extensionOf(name);

    if (!allowedExtensions.contains(extension)) {
      throw FormatException('El formato .$extension no está permitido.');
    }

    if (type.isImage && !_isImageExtension(extension)) {
      throw const FormatException(
        'La portada y la galería solo admiten archivos de imagen.',
      );
    }

    if (type.isAttachment && _isImageExtension(extension)) {
      throw const FormatException(
        'Usa la sección de imágenes para agregar archivos gráficos.',
      );
    }

    _requireBytes(file);
  }

  Uint8List _requireBytes(PlatformFile file) {
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'No se pudieron leer los datos del archivo seleccionado.',
      );
    }

    return bytes;
  }

  String _buildStoragePath({
    required String publicationId,
    required PublicationAssetType type,
    required String extension,
  }) {
    final generatedName = const Uuid().v4();

    return '$publicationId/${type.value}/$generatedName.$extension';
  }

  String _extensionOf(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final separator = normalized.lastIndexOf('.');

    if (separator < 0 || separator == normalized.length - 1) {
      throw const FormatException(
        'El archivo seleccionado no tiene una extensión válida.',
      );
    }

    return normalized.substring(separator + 1);
  }

  bool _isImageExtension(String extension) {
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
      'heif',
    }.contains(extension);
  }

  String _mimeTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.'
            'wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.'
            'spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.'
            'presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        throw FormatException(
          'No se pudo determinar el tipo MIME para .$extension.',
        );
    }
  }

  void _validatePublicationId(String publicationId) {
    if (publicationId.trim().isEmpty) {
      throw ArgumentError.value(
        publicationId,
        'publicationId',
        'A publication identifier is required.',
      );
    }
  }
}
