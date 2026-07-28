import 'publication_asset_type.dart';

/// Metadata for one file associated with an institutional publication.
///
/// The object itself is stored in a private Supabase Storage bucket.
/// This model stores only its controlled metadata and Storage path.
class PublicationAsset {
  const PublicationAsset({
    required this.id,
    required this.publicationId,
    required this.type,
    required this.storageBucket,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.displayOrder,
    required this.uploadedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultBucket = 'institutional-publications';

  final String id;
  final String publicationId;
  final PublicationAssetType type;
  final String storageBucket;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final int displayOrder;
  final String uploadedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isImage => type.isImage || mimeType.startsWith('image/');

  bool get isPdf => mimeType == 'application/pdf';

  String get extension {
    final index = originalName.lastIndexOf('.');

    if (index < 0 || index == originalName.length - 1) {
      return '';
    }

    return originalName.substring(index + 1).toLowerCase();
  }

  factory PublicationAsset.fromSupabase(Map<String, dynamic> row) {
    return PublicationAsset(
      id: row['id'] as String? ?? '',
      publicationId: row['publication_id'] as String? ?? '',
      type: PublicationAssetType.fromValue(row['asset_type'] as String?),
      storageBucket: row['storage_bucket'] as String? ?? defaultBucket,
      storagePath: row['storage_path'] as String? ?? '',
      originalName: row['original_name'] as String? ?? '',
      mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: _readInt(row['size_bytes']),
      displayOrder: _readInt(row['display_order']),
      uploadedBy: row['uploaded_by'] as String? ?? '',
      createdAt:
          _readDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id.isNotEmpty) 'id': id,
      'publication_id': publicationId,
      'asset_type': type.value,
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'original_name': originalName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'display_order': displayOrder,
      'uploaded_by': uploadedBy,
    };
  }

  PublicationAsset copyWith({
    String? id,
    String? publicationId,
    PublicationAssetType? type,
    String? storageBucket,
    String? storagePath,
    String? originalName,
    String? mimeType,
    int? sizeBytes,
    int? displayOrder,
    String? uploadedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicationAsset(
      id: id ?? this.id,
      publicationId: publicationId ?? this.publicationId,
      type: type ?? this.type,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      displayOrder: displayOrder ?? this.displayOrder,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
