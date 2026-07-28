/// Defines the purpose of one institutional publication asset.
enum PublicationAssetType {
  cover,
  image,
  attachment;

  String get value {
    switch (this) {
      case PublicationAssetType.cover:
        return 'cover';
      case PublicationAssetType.image:
        return 'image';
      case PublicationAssetType.attachment:
        return 'attachment';
    }
  }

  bool get isCover => this == PublicationAssetType.cover;

  bool get isImage =>
      this == PublicationAssetType.cover || this == PublicationAssetType.image;

  bool get isAttachment => this == PublicationAssetType.attachment;

  static PublicationAssetType fromValue(String? value) {
    switch (value) {
      case 'cover':
        return PublicationAssetType.cover;
      case 'image':
        return PublicationAssetType.image;
      case 'attachment':
      default:
        return PublicationAssetType.attachment;
    }
  }
}
