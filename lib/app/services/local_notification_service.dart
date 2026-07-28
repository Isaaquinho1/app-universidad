import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const channelId = 'institutional_announcements';
  static const channelName = 'Comunicados institucionales';
  static const channelDescription =
      'Notificaciones sobre comunicados institucionales de Conecta ITT.';

  static const _maxNotificationImageBytes = 10 * 1024 * 1024;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    if (_initialized || kIsWeb) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      'ic_stat_ic_notification',
    );

    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;

        if (payload == null || payload.isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(payload);

          if (decoded is Map) {
            onNotificationTap(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (_) {
          // Ignore malformed notification payloads.
        }
      },
    );

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Conecta ITT';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'Tienes un nuevo comunicado institucional.';

    final imageUrl = message.data['image_url']?.toString().trim();

    final imageBytes = await _downloadNotificationImage(imageUrl);

    final StyleInformation? styleInformation =
        imageBytes == null
            ? null
            : BigPictureStyleInformation(
              ByteArrayAndroidBitmap(imageBytes),
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_ic_notification',
      styleInformation: styleInformation,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );

    Logger().i(
      'Foreground local notification displayed: '
      'title=$title, '
      'hasImage=${imageBytes != null}, '
      'data=${message.data}',
    );
  }

  Future<Uint8List?> _downloadNotificationImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(imageUrl);

    if (uri == null || !uri.hasScheme) {
      Logger().w('Notification image URL is invalid.');
      return null;
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        Logger().w(
          'Notification image download returned '
          'HTTP ${response.statusCode}.',
        );
        return null;
      }

      final bytes = response.bodyBytes;

      if (bytes.isEmpty || bytes.length > _maxNotificationImageBytes) {
        Logger().w('Notification image was empty or exceeded 10 MiB.');
        return null;
      }

      return bytes;
    } catch (error, stackTrace) {
      Logger().w(
        'Notification image could not be downloaded.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
