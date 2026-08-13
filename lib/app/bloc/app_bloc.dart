import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:conecta_itt/app/theme/theme_mode.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_restoration_service.dart';
import 'package:conecta_itt/app/services/services.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:user_repository/user_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends HydratedBloc<AppEvent, AppState> {
  AppBloc({
    required FirebaseMessaging firebaseMessaging,
    required UserRepository userRepository,
    required AppUserProfileRepository appUserProfileRepository,
    required User user,
  }) : _firebaseMessaging = firebaseMessaging,
       _userRepository = userRepository,
       _appUserProfileRepository = appUserProfileRepository,
       super(
         user == User.anonymous
             ? const AppState.unauthenticated()
             : AppState.authenticated(user),
       ) {
    on<AppOpened>(_onAppOpened);
    on<RecieveInteractedMessage>(_onRecieveInteractedMessage);
    on<AnnouncementNotificationOpened>(_onAnnouncementNotificationOpened);
    on<AnnouncementNavigationConsumed>(_onAnnouncementNavigationConsumed);
    on<AcademicTaskNotificationOpened>(_onAcademicTaskNotificationOpened);
    on<AcademicTaskNavigationConsumed>(_onAcademicTaskNavigationConsumed);
    on<ThemeChanged>(_onThemeChanged);
    on<AppUserChanged>(_onUserChanged);
    on<AppInstitutionalProfileChanged>(_onInstitutionalProfileChanged);
    on<AppLogoutRequested>(_onLogoutRequested);

    _userSubscription = _userRepository.user.listen(_userChanged);
  }

  final UserRepository _userRepository;
  final FirebaseMessaging _firebaseMessaging;
  final AppUserProfileRepository _appUserProfileRepository;

  late final StreamSubscription<User> _userSubscription;
  StreamSubscription<AppUserProfile?>? _institutionalProfileSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const _notificationDeviceIdKey =
      'institutional_notification_device_id';

  void _userChanged(User user) => add(AppUserChanged(user));

  Future<void> _registerNotificationsForUser(String uid) async {
    if (uid.isEmpty) {
      return;
    }

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final authorizationGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorizationGranted) {
        Logger().i('Notification permission was not granted.');
        return;
      }

      if (!_isSupportedNotificationPlatform()) {
        Logger().w(
          'Notification registration is only supported on Android and iOS.',
        );
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _waitForApplePushToken();
      }

      final token = await _firebaseMessaging.getToken();

      if (token == null || token.trim().isEmpty) {
        Logger().w('Firebase Messaging did not return an FCM token.');
        return;
      }

      final deviceId = await _getOrCreateNotificationDeviceId();
      final platform = _notificationPlatform();

      await _appUserProfileRepository.updateFcmToken(
        uid: uid,
        deviceId: deviceId,
        token: token,
        platform: platform,
      );

      await _fcmTokenRefreshSubscription?.cancel();

      _fcmTokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen(
        (refreshedToken) {
          unawaited(
            _persistRefreshedFcmToken(
              uid: uid,
              deviceId: deviceId,
              platform: platform,
              token: refreshedToken,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          addError(error, stackTrace);
        },
      );

      Logger().i(
        'FCM token registered for platform $platform '
        'and installation $deviceId.',
      );
    } catch (error, stackTrace) {
      Logger().w(
        'FCM token registration could not be completed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistRefreshedFcmToken({
    required String uid,
    required String deviceId,
    required String platform,
    required String token,
  }) async {
    try {
      await _appUserProfileRepository.updateFcmToken(
        uid: uid,
        deviceId: deviceId,
        token: token,
        platform: platform,
      );

      Logger().i('Refreshed FCM token stored successfully.');
    } catch (error, stackTrace) {
      Logger().w(
        'Refreshed FCM token could not be stored.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _waitForApplePushToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _firebaseMessaging.getAPNSToken();

      if (token != null && token.isNotEmpty) {
        return;
      }

      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    Logger().w('APNs token was not available before requesting the FCM token.');
  }

  Future<String> _getOrCreateNotificationDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final storedId = preferences.getString(_notificationDeviceIdKey);

    if (storedId != null && storedId.trim().isNotEmpty) {
      return storedId;
    }

    final generatedId = const Uuid().v4();

    await preferences.setString(_notificationDeviceIdKey, generatedId);

    return generatedId;
  }

  bool _isSupportedNotificationPlatform() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _notificationPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ =>
        throw UnsupportedError(
          'Notification tokens are only supported on Android and iOS.',
        ),
    };
  }

  Future<void> _onUserChanged(
    AppUserChanged event,
    Emitter<AppState> emit,
  ) async {
    final user = event.user;

    await _institutionalProfileSubscription?.cancel();
    _institutionalProfileSubscription = null;

    if (user == User.anonymous) {
      await _fcmTokenRefreshSubscription?.cancel();
      _fcmTokenRefreshSubscription = null;

      emit(AppState.unauthenticated(isAmoled: state.isAmoled));
      return;
    }

    final profile = await _appUserProfileRepository.ensureStudentProfile(
      uid: user.id,
      email: user.email,
      displayName: user.name,
    );

    final nextStatus =
        user.isNewUser ? AppStatus.onboardingRequired : AppStatus.authenticated;

    emit(
      state.copyWith(
        status: nextStatus,
        user: user,
        institutionalProfile: profile,
      ),
    );

    unawaited(_registerNotificationsForUser(user.id));

    _institutionalProfileSubscription = _appUserProfileRepository
        .watchProfile(user.id)
        .listen(
          (profile) {
            add(AppInstitutionalProfileChanged(profile));
          },
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
          },
        );
  }

  void _onInstitutionalProfileChanged(
    AppInstitutionalProfileChanged event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn) {
      return;
    }

    emit(
      state.copyWith(
        institutionalProfile: event.profile,
        clearInstitutionalProfile: event.profile == null,
      ),
    );
  }

  void _onLogoutRequested(AppLogoutRequested event, Emitter<AppState> emit) {
    unawaited(_userRepository.logOut());
  }

  @override
  Future<void> close() async {
    await _foregroundMessageSubscription?.cancel();
    await _fcmTokenRefreshSubscription?.cancel();
    await _institutionalProfileSubscription?.cancel();
    await _userSubscription.cancel();
    return super.close();
  }

  Future<void> setupInteractedMessage(Emitter<AppState> emit) async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(emit, initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(emit, message);
    });
  }

  void _handleMessage(Emitter<AppState> emit, RemoteMessage message) {
    add(RecieveInteractedMessage(message));
  }

  void _onRecieveInteractedMessage(
    RecieveInteractedMessage event,
    Emitter<AppState> _,
  ) {
    final data = event.message.data;
    Logger().i('Handling message: $data');
    _queueAnnouncementNavigation(data);
  }

  void _onAnnouncementNotificationOpened(
    AnnouncementNotificationOpened event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn || event.announcementId.isEmpty) {
      return;
    }

    emit(state.copyWith(pendingAnnouncementId: event.announcementId));
  }

  void _onAnnouncementNavigationConsumed(
    AnnouncementNavigationConsumed event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(clearPendingAnnouncementId: true));
  }

  void _onAcademicTaskNotificationOpened(
    AcademicTaskNotificationOpened event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn || event.taskId.isEmpty) {
      return;
    }

    emit(state.copyWith(pendingAcademicTaskId: event.taskId));
  }

  void _onAcademicTaskNavigationConsumed(
    AcademicTaskNavigationConsumed event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(clearPendingAcademicTaskId: true));
  }

  Future<void> _onAppOpened(AppOpened event, Emitter<AppState> emit) async {
    await LocalNotificationService.instance.initialize(
      onNotificationTap: (data) {
        _handleNotificationData(data);
      },
    );

    // Reconcilia recordatorios académicos persistidos con las
    // notificaciones locales sin bloquear el arranque de la app.
    unawaited(AcademicReminderRestorationService().restore());

    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) {
        Logger().i(
          'Foreground FCM message received: '
          'id=${message.messageId}, '
          'data=${message.data}, '
          'title=${message.notification?.title}',
        );

        unawaited(LocalNotificationService.instance.showRemoteMessage(message));
      },
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );

    await setupInteractedMessage(emit);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    Logger().i('Handling local notification tap: $data');

    final type = data['type']?.toString().trim();

    if (type == 'academic_task') {
      final taskId = data['task_id']?.toString().trim();

      if (taskId == null || taskId.isEmpty) {
        Logger().w('Academic reminder interaction did not contain a task_id.');
        return;
      }

      add(AcademicTaskNotificationOpened(taskId));
      return;
    }

    _queueAnnouncementNavigation(data);
  }

  void _queueAnnouncementNavigation(Map<String, dynamic> data) {
    final announcementId = data['announcement_id']?.toString().trim();

    if (announcementId == null || announcementId.isEmpty) {
      Logger().w(
        'Notification interaction did not contain an announcement_id.',
      );
      return;
    }

    add(AnnouncementNotificationOpened(announcementId));
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<AppState> emit,
  ) async {
    CustomThemeMode.setAmoled(event.isAmoled);
    emit(state.copyWith(isAmoled: event.isAmoled));
  }

  @override
  AppState? fromJson(Map<String, dynamic> json) {
    try {
      return AppState(
        isAmoled: json['isAmoled'] as bool? ?? false,
        status: AppStatus.values[json['status'] as int? ?? 0],
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(AppState state) {
    try {
      return {'isAmoled': state.isAmoled, 'status': state.status.index};
    } catch (_) {
      return null;
    }
  }
}
