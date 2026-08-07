import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const channelId = 'institutional_announcements';
  static const channelName = 'Comunicados institucionales';
  static const channelDescription =
      'Notificaciones sobre comunicados institucionales de Conecta ITT.';

  static const academicReminderChannelId = 'academic_reminders';
  static const academicReminderChannelName = 'Recordatorios académicos';
  static const academicReminderChannelDescription =
      'Avisos de tareas, entregas y actividades académicas próximas.';

  static const _maxNotificationImageBytes = 10 * 1024 * 1024;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneInitialized = false;

  Future<void> initialize({
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    if (_initialized || kIsWeb) {
      return;
    }

    _initializeTimeZone();

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
          // Ignora payloads mal formados.
        }
      },
    );

    await _createAndroidChannels();

    _initialized = true;
  }

  void _initializeTimeZone() {
    if (_timeZoneInitialized) {
      return;
    }

    tz_data.initializeTimeZones();

    // Conecta ITT pertenece al TecNM Campus Tlalpan, CDMX.
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    _timeZoneInitialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) {
      return;
    }

    const announcementsChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    const remindersChannel = AndroidNotificationChannel(
      academicReminderChannelId,
      academicReminderChannelName,
      description: academicReminderChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin.createNotificationChannel(announcementsChannel);

    await androidPlugin.createNotificationChannel(remindersChannel);
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) {
      return false;
    }

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? true;
    }

    final darwinPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

    if (darwinPlugin != null) {
      return await darwinPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) {
      return false;
    }

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) {
      return true;
    }

    final alreadyAllowed =
        await androidPlugin.canScheduleExactNotifications() ?? false;

    if (alreadyAllowed) {
      return true;
    }

    await androidPlugin.requestExactAlarmsPermission();

    return await androidPlugin.canScheduleExactNotifications() ?? false;
  }

  Future<bool> canScheduleExactNotifications() async {
    if (kIsWeb) {
      return false;
    }

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) {
      return true;
    }

    return await androidPlugin.canScheduleExactNotifications() ?? false;
  }

  Future<void> scheduleAcademicReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (!_initialized) {
      throw StateError(
        'LocalNotificationService debe inicializarse antes de programar.',
      );
    }

    _initializeTimeZone();

    final now = DateTime.now();

    if (!scheduledAt.isAfter(now)) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'El recordatorio debe programarse en el futuro.',
      );
    }

    final exactAllowed = await canScheduleExactNotifications();

    const androidDetails = AndroidNotificationDetails(
      academicReminderChannelId,
      academicReminderChannelName,
      channelDescription: academicReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_ic_notification',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final localDate = scheduledAt.toLocal();

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        localDate.year,
        localDate.month,
        localDate.day,
        localDate.hour,
        localDate.minute,
        localDate.second,
      ),
      notificationDetails: details,
      androidScheduleMode:
          exactAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(payload),
    );

    Logger().i(
      'Academic reminder scheduled: '
      'id=$id, '
      'scheduledAt=${scheduledAt.toIso8601String()}, '
      'exact=$exactAllowed.',
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      return;
    }

    await _plugin.cancel(id: id);

    Logger().i('Local notification cancelled: id=$id.');
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (kIsWeb) {
      return const [];
    }

    return _plugin.pendingNotificationRequests();
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
