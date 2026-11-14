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

  Future<Map<String, dynamic>> runScenario({
    required bool conflict,
    required int notificationStatus,
    Map<String, dynamic>? notificationPayload,
    required void Function() onUpdate,
    required void Function() onNotification,
  }) async {
    final mockHttp = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/rest/v1/announcements') &&
          request.method == 'PATCH') {
        onUpdate();

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['status'], 'published');

        return http.Response(
          jsonEncode(
            conflict
                ? <Map<String, dynamic>>[]
                : <Map<String, dynamic>>[
                  {'id': announcementId},
                ],
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      if (path.endsWith('/functions/v1/send-announcement-notification') &&
          request.method == 'POST') {
        onNotification();

        return http.Response(
          jsonEncode(
            notificationPayload ??
                {
                  'error': 'The notification dispatch failed.',
                  'details': 'Fallo de FCM simulado',
                },
          ),
          notificationStatus,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      throw StateError(
        'Solicitud HTTP inesperada: '
        '${request.method} ${request.url}',
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

      expect(supabase.auth.currentUser?.id, userId);

      final now = DateTime.now().toUtc();

      final announcement = Announcement.fromSupabase({
        'id': announcementId,
        'title': 'Publicacion simulada',
        'body': 'Contenido de prueba',
        'author_id': userId,
        'status': 'draft',
        'priority': 'normal',
        'content_type': 'news',
        'created_at':
            now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'updated_at':
            now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'content_version': 1,
        'all_users': true,
      });

      final repository = AnnouncementRepository(supabaseClient: supabase);

      return await repository.publishAnnouncement(announcement);
    } finally {
      supabase.dispose();
      mockHttp.close();
    }
  }

  test('Publicacion guardada conserva advertencia si FCM falla', () async {
    var updates = 0;
    var notifications = 0;

    final result = await runScenario(
      conflict: false,
      notificationStatus: 500,
      onUpdate: () => updates++,
      onNotification: () => notifications++,
    );

    expect(updates, 1);
    expect(notifications, 1);

    expect(result['publication_saved'], isTrue);
    expect(result['notification_issue'], isTrue);
    expect(result['notification_error'], isNotNull);
  });

  test('Conflicto de publicacion impide enviar FCM', () async {
    var updates = 0;
    var notifications = 0;

    await expectLater(
      runScenario(
        conflict: true,
        notificationStatus: 200,
        onUpdate: () => updates++,
        onNotification: () => notifications++,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'mensaje',
          contains('La publicación cambió'),
        ),
      ),
    );

    expect(updates, 1);
    expect(notifications, 0);
  });

  test('FCM parcial conserva sus metricas', () async {
    var updates = 0;
    var notifications = 0;

    final result = await runScenario(
      conflict: false,
      notificationStatus: 200,
      notificationPayload: {
        'dispatch_id': '33333333-3333-4333-8333-333333333333',
        'announcement_id': announcementId,
        'content_version': 1,
        'audience_count': 4,
        'token_count': 3,
        'sent_count': 2,
        'failed_count': 1,
        'no_token_count': 1,
        'invalid_token_count': 0,
      },
      onUpdate: () => updates++,
      onNotification: () => notifications++,
    );

    expect(updates, 1);
    expect(notifications, 1);
    expect(result['publication_saved'], isTrue);
    expect(result['notification_issue'], isFalse);
    expect(result['sent_count'], 2);
    expect(result['failed_count'], 1);
    expect(result['no_token_count'], 1);
  });

  test('Respuesta FCM incompleta no confirma el envio', () async {
    var updates = 0;
    var notifications = 0;

    final result = await runScenario(
      conflict: false,
      notificationStatus: 200,
      notificationPayload: {
        'dispatch_id': '33333333-3333-4333-8333-333333333333',
        'sent_count': 2,
      },
      onUpdate: () => updates++,
      onNotification: () => notifications++,
    );

    expect(updates, 1);
    expect(notifications, 1);
    expect(result['publication_saved'], isTrue);
    expect(
      result['notification_issue'],
      isTrue,
      reason: 'Faltan las metricas para confirmar el despacho FCM.',
    );
  });

  test('FCM rechaza contadores inconsistentes', () async {
    var updates = 0;
    var notifications = 0;

    final result = await runScenario(
      conflict: false,
      notificationStatus: 200,
      notificationPayload: {
        'dispatch_id': '33333333-3333-4333-8333-333333333333',
        'audience_count': 4,
        'token_count': 3,
        'sent_count': 2,
        'failed_count': 0,
        'no_token_count': 1,
        'invalid_token_count': 0,
      },
      onUpdate: () => updates++,
      onNotification: () => notifications++,
    );

    expect(updates, 1);
    expect(notifications, 1);
    expect(result['publication_saved'], isTrue);
    expect(result['notification_issue'], isTrue);
    expect(result['notification_error'].toString(), contains('inconsistentes'));
  });

  test('FCM rechaza contadores negativos', () async {
    var updates = 0;
    var notifications = 0;

    final result = await runScenario(
      conflict: false,
      notificationStatus: 200,
      notificationPayload: {
        'dispatch_id': '33333333-3333-4333-8333-333333333333',
        'audience_count': 4,
        'token_count': 3,
        'sent_count': 3,
        'failed_count': -1,
        'no_token_count': 1,
        'invalid_token_count': 0,
      },
      onUpdate: () => updates++,
      onNotification: () => notifications++,
    );

    expect(updates, 1);
    expect(notifications, 1);
    expect(result['publication_saved'], isTrue);
    expect(result['notification_issue'], isTrue);
    expect(
      result['notification_error'].toString(),
      contains('incompleta o inválida'),
    );
  });

  test('Publicacion exitosa conserva metricas FCM', () async {
    var updateRequests = 0;
    var notificationRequests = 0;

    final mockHttp = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/rest/v1/announcements') &&
          request.method == 'PATCH') {
        updateRequests++;

        expect(request.url.queryParameters['id'], 'eq.$announcementId');

        expect(request.url.queryParameters['status'], 'eq.draft');

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['status'], 'published');
        expect(body['published_at'], isNotNull);
        expect(body['expires_at'], isNotNull);

        return http.Response(
          jsonEncode([
            {'id': announcementId},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      if (path.endsWith('/functions/v1/send-announcement-notification') &&
          request.method == 'POST') {
        notificationRequests++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['announcement_id'], announcementId);

        return http.Response(
          jsonEncode({
            'dispatch_id': '33333333-3333-4333-8333-333333333333',
            'announcement_id': announcementId,
            'content_version': 1,
            'audience_count': 3,
            'token_count': 2,
            'sent_count': 2,
            'failed_count': 0,
            'no_token_count': 1,
            'invalid_token_count': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }

      throw StateError(
        'Solicitud HTTP inesperada: '
        '${request.method} ${request.url}',
      );
    });

    final supabase = SupabaseClient(
      'https://conecta-itt-test.invalid',
      'clave-publica-ficticia',
      httpClient: mockHttp,
    );

    addTearDown(() async {
      supabase.dispose();
      mockHttp.close();
    });

    // Sesion totalmente ficticia y con vencimiento futuro.
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
      'title': 'Publicacion de prueba',
      'body': 'Contenido ficticio',
      'author_id': userId,
      'status': 'draft',
      'priority': 'normal',
      'content_type': 'news',
      'created_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      'updated_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      'content_version': 1,
      'all_users': true,
    });

    final repository = AnnouncementRepository(supabaseClient: supabase);

    final result = await repository.publishAnnouncement(announcement);

    expect(result['publication_saved'], isTrue);
    expect(result['notification_issue'], isFalse);
    expect(result['sent_count'], 2);
    expect(result['failed_count'], 0);
    expect(result['no_token_count'], 1);

    expect(updateRequests, 1);
    expect(notificationRequests, 1);
  });
}
