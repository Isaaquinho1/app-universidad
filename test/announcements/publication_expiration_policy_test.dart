import 'package:conecta_itt/announcements/models/'
    'publication_content_type.dart';
import 'package:conecta_itt/announcements/models/'
    'publication_expiration_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublicationExpirationPolicy', () {
    final publishedAt = DateTime.utc(2026, 11, 10, 12);

    test('noticias: 30 días', () {
      final expiration = PublicationExpirationPolicy.defaultExpiration(
        contentType: PublicationContentType.news,
        publishedAt: publishedAt,
      );

      expect(expiration, publishedAt.add(const Duration(days: 30)));
    });

    test('comunicados: 90 días', () {
      final expiration = PublicationExpirationPolicy.defaultExpiration(
        contentType: PublicationContentType.announcement,
        publishedAt: publishedAt,
      );

      expect(expiration, publishedAt.add(const Duration(days: 90)));
    });

    test('la fecha de vencimiento se normaliza a UTC', () {
      final localPublishedAt = DateTime.parse('2026-11-10T06:00:00-06:00');

      final expiration = PublicationExpirationPolicy.defaultExpiration(
        contentType: PublicationContentType.news,
        publishedAt: localPublishedAt,
      );

      expect(expiration.isUtc, isTrue);
      expect(expiration, DateTime.utc(2026, 12, 10, 12));
    });
  });
}
