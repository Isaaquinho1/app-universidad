import 'dart:convert';

import 'package:conecta_itt/announcements/models/announcement.dart';
import 'package:conecta_itt/announcements/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const announcementId = '11111111-1111-4111-8111-111111111111';
  const userId = '22222222-2222-4222-8222-222222222222';

  test('Conflicto de version rechaza edicion sin enviar FCM', () async {
    var updateRequests = 0;
    var notificationRequests = 0;

    final mockHttp = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/rest/v1/rpc/update_announcement_with_targets') &&
          request.method == 'POST') {
        updateRequests++;

        final payload = jsonDecode(request.body) as Map<String, dynamic>;

        expect(payload['p_announcement_id'], announcementId);

        final announcement = payload['p_announcement'] as Map<String, dynamic>;

        expect(announcement['status'], 'published');
        expect(announcement['expected_content_version'], 7);

        return http.Response(
          jsonEncode({
            'code': 'P0001',
            'message': 'PUBLICATION_VERSION_CONFLICT',
            'details': null,
            'hint': null,
          }),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      if (path.endsWith('/functions/v1/send-announcement-notification') &&
          request.method == 'POST') {
        notificationRequests++;

        final payload = jsonDecode(request.body) as Map<String, dynamic>;

        expect(payload['announcement_id'], announcementId);

        return http.Response(
          jsonEncode({
            'error': 'The notification dispatch failed.',
            'details': 'Fallo FCM simulado tras edición',
          }),
          500,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      throw StateError(
        'Solicitud inesperada: ${request.method} ${request.url}',
      );
    });

    final supabase = SupabaseClient(
      'https://conecta-itt-test.invalid',
      'clave-publica-ficticia',
      httpClient: mockHttp,
    );

    addTearDown(() {
      supabase.dispose();
      mockHttp.close();
    });

    final session = {
      'access_token': 'token-ficticio',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': 4102444800,
      'refresh_token': 'refresh-ficticio',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'prueba@example.invalid',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00.000Z',
      },
    };

    await supabase.auth.recoverSession(jsonEncode(session));

    expect(supabase.auth.currentUser?.id, userId);

    final now = DateTime.now().toUtc();

    final announcement = Announcement.fromSupabase({
      'id': announcementId,
      'title': 'Comunicado institucional actualizado',
      'body': 'Contenido de prueba para una edición',
      'author_id': userId,
      'status': 'published',
      'priority': 'normal',
      'content_type': 'announcement',
      'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'published_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'expires_at': now.add(const Duration(days: 89)).toIso8601String(),
      'all_users': true,
      'content_version': 7,
    });

    final repository = AnnouncementRepository(supabaseClient: supabase);

    await expectLater(
      repository.updateAnnouncement(announcement),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.message,
          'mensaje',
          contains('PUBLICATION_VERSION_CONFLICT'),
        ),
      ),
    );

    expect(updateRequests, 1);
    expect(notificationRequests, 0);
  });
}
