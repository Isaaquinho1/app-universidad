import 'publication_content_type.dart';

/// Política inicial de vigencia para publicaciones institucionales.
///
/// No borra registros ni cambia automáticamente su estado a archived.
abstract final class PublicationExpirationPolicy {
  static const newsDays = 30;
  static const announcementDays = 90;

  static DateTime defaultExpiration({
    required PublicationContentType contentType,
    required DateTime publishedAt,
  }) {
    final days = contentType.isNews ? newsDays : announcementDays;

    return publishedAt.toUtc().add(Duration(days: days));
  }
}
