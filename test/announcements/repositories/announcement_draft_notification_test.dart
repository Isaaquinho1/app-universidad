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

  Future<void> verifyDraft({required bool editing}) async {
    var rpcRequests = 0;
    var notificationRequests = 0;

    final expectedRpc =
        editing
            ? 'update_announcement_with_targets'
            : 'create_announcement_with_targets';

    final mockHttp = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/rest/v1/rpc/$expectedRpc') &&
          request.method == 'POST') {
        rpcRequests++;

        final payload = jsonDecode(request.body) as Map<String, dynamic>;

        final values = payload['p_announcement'] as Map<String, dynamic>;

        expect(values['status'], 'draft');

        if (editing) {
          expect(payload['p_announcement_id'], announcementId);
        }

        return http.Response(
          jsonEncode(announcementId),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      if (path.endsWith('/functions/v1/send-announcement-notification')) {
        notificationRequests++;

        throw StateError('SEGURIDAD: un borrador no debe invocar FCM.');
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

    try {
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

      final now = DateTime.now().toUtc();

      final announcement = Announcement.fromSupabase({
        'id': editing ? announcementId : '',
        'title': 'Borrador institucional',
        'body': 'Contenido de prueba',
        'author_id': userId,
        'status': 'draft',
        'priority': 'normal',
        'content_type': 'news',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'all_users': true,
      });

      final repository = AnnouncementRepository(supabaseClient: supabase);

      final result =
          editing
              ? await repository.updateAnnouncement(announcement)
              : await repository.createAnnouncement(announcement);

      expect(result.id, announcementId);
      expect(result.notification, isNull);
      expect(rpcRequests, 1);
      expect(notificationRequests, 0);
    } finally {
      supabase.dispose();
      mockHttp.close();
    }
  }

  test('Crear borrador no envia FCM', () async {
    await verifyDraft(editing: false);
  });

  test('Editar borrador no envia FCM', () async {
    await verifyDraft(editing: true);
  });
}
