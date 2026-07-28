/// Defines the functional type of an institutional publication.
enum PublicationContentType {
  announcement,
  news;

  String get value {
    switch (this) {
      case PublicationContentType.announcement:
        return 'announcement';
      case PublicationContentType.news:
        return 'news';
    }
  }

  bool get isAnnouncement => this == PublicationContentType.announcement;

  bool get isNews => this == PublicationContentType.news;

  String get label {
    switch (this) {
      case PublicationContentType.announcement:
        return 'Comunicado';
      case PublicationContentType.news:
        return 'Noticia';
    }
  }

  static PublicationContentType fromValue(String? value) {
    switch (value) {
      case 'news':
        return PublicationContentType.news;
      case 'announcement':
      default:
        return PublicationContentType.announcement;
    }
  }
}
