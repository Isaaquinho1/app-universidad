import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:conecta_itt/app/theme/theme_mode.dart';
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
       _latestAuthUserId = user.id,
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
    on<ClassSessionNotificationOpened>(_onClassSessionNotificationOpened);
    on<ClassSessionNavigationConsumed>(_onClassSessionNavigationConsumed);
    on<ThemeChanged>(_onThemeChanged);
    on<AppUserChanged>(_onUserChanged);
    on<AppProfileRetryRequested>(_onProfileRetryRequested);
    on<AppInstitutionalProfileChanged>(_onInstitutionalProfileChanged);
    on<AppLogoutRequested>(_onLogoutRequested);

    _userSubscription = _userRepository.user.listen(_userChanged);
  }

  final UserRepository _userRepository;
  final FirebaseMessaging _firebaseMessaging;
  final AppUserProfileRepository _appUserProfileRepository;
  String _latestAuthUserId;
  User? _retryUser;
  int _authRevision = 0;
  final StreamController<int> _authRevisionController =
      StreamController<int>.broadcast(sync: true);

  int get authRevision => _authRevision;

  Stream<int> get authRevisionChanges => _authRevisionController.stream;

  late final StreamSubscription<User> _userSubscription;
  StreamSubscription<AppUserProfile?>? _institutionalProfileSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const _notificationDeviceIdKey =
      'institutional_notification_device_id';

  void _userChanged(User user) {
    _latestAuthUserId = user.id;
    _authRevision++;

    _authRevisionController.add(_authRevision);

    add(AppUserChanged(user, revision: _authRevision));
  }

  bool _isCurrentAuth(String uid, int revision) =>
      !isClosed &&
      uid.isNotEmpty &&
      _latestAuthUserId == uid &&
      _authRevision == revision;

  Future<void> _registerNotificationsForUser(String uid, int revision) async {
    if (!_isCurrentAuth(uid, revision)) {
      return;
    }

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (!_isCurrentAuth(uid, revision)) return;

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
        final apnsReady = await _waitForApplePushToken();

        if (!_isCurrentAuth(uid, revision)) return;

        if (!apnsReady) {
          Logger().w('FCM registration deferred: APNs token is unavailable.');
          return;
        }
      }

      final token = await _firebaseMessaging.getToken();
      if (!_isCurrentAuth(uid, revision)) return;

      if (token == null || token.trim().isEmpty) {
        Logger().w('Firebase Messaging did not return an FCM token.');
        return;
      }

      final deviceId = await _getOrCreateNotificationDeviceId();
      if (!_isCurrentAuth(uid, revision)) return;
      final platform = _notificationPlatform();

      await _appUserProfileRepository.updateFcmToken(
        uid: uid,
        deviceId: deviceId,
        token: token,
        platform: platform,
      );

      if (!_isCurrentAuth(uid, revision)) return;

      final previousSubscription = _fcmTokenRefreshSubscription;
      _fcmTokenRefreshSubscription = null;
      await previousSubscription?.cancel();

      if (!_isCurrentAuth(uid, revision)) return;

      _fcmTokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen(
        (refreshedToken) {
          if (!_isCurrentAuth(uid, revision)) return;
          unawaited(
            _persistRefreshedFcmToken(
              revision: revision,
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
    required int revision,
    required String uid,
    required String deviceId,
    required String platform,
    required String token,
  }) async {
    if (!_isCurrentAuth(uid, revision)) return;

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

  Future<bool> _waitForApplePushToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final token = await _firebaseMessaging.getAPNSToken();

        if (token != null && token.isNotEmpty) {
          Logger().i('APNs token is available.');
          return true;
        }
      } catch (error, stackTrace) {
        Logger().w(
          'Could not obtain the APNs token.',
          error: error,
          stackTrace: stackTrace,
        );
        return false;
      }

      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    Logger().w('APNs token was not available after registration attempts.');
    return false;
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

  void _onProfileRetryRequested(
    AppProfileRetryRequested event,
    Emitter<AppState> emit,
  ) {
    if (state.status != AppStatus.profileLoadFailed) return;

    final user = _retryUser;
    if (user == null ||
        user == User.anonymous ||
        user.id != _latestAuthUserId) {
      return;
    }

    add(AppUserChanged(user, revision: _authRevision));
  }

  Future<void> _onUserChanged(
    AppUserChanged event,
    Emitter<AppState> emit,
  ) async {
    final user = event.user;

    if (emit.isDone ||
        _latestAuthUserId != user.id ||
        event.revision != _authRevision) {
      return;
    }

    _retryUser = user;

    // No mantener visible la cuenta anterior mientras se carga
    // el perfil institucional de una cuenta diferente.
    if ((state.status.isLoggedIn && state.user.id != user.id) ||
        (user != User.anonymous &&
            state.status == AppStatus.profileLoadFailed)) {
      emit(
        AppState(status: AppStatus.switchingAccount, isAmoled: state.isAmoled),
      );
    }

    // Desvincular las suscripciones de la sesión anterior.
    final previousProfileSubscription = _institutionalProfileSubscription;
    final previousTokenSubscription = _fcmTokenRefreshSubscription;
    _institutionalProfileSubscription = null;
    _fcmTokenRefreshSubscription = null;

    await previousProfileSubscription?.cancel();
    await previousTokenSubscription?.cancel();

    if (emit.isDone ||
        _latestAuthUserId != user.id ||
        event.revision != _authRevision) {
      return;
    }

    if (user == User.anonymous) {
      if (emit.isDone ||
          _latestAuthUserId != user.id ||
          event.revision != _authRevision) {
        return;
      }

      emit(AppState.unauthenticated(isAmoled: state.isAmoled));
      return;
    }

    late final AppUserProfile profile;

    try {
      profile = await _appUserProfileRepository.ensureStudentProfile(
        uid: user.id,
        email: user.email,
        displayName: user.name,
      );
    } catch (error, stackTrace) {
      if (emit.isDone ||
          _latestAuthUserId != user.id ||
          event.revision != _authRevision) {
        return;
      }

      Logger().w(
        'No se pudo cargar el perfil institucional.',
        error: error,
        stackTrace: stackTrace,
      );

      emit(
        AppState(status: AppStatus.profileLoadFailed, isAmoled: state.isAmoled),
      );
      return;
    }

    if (emit.isDone ||
        _latestAuthUserId != user.id ||
        event.revision != _authRevision) {
      return;
    }

    final nextStatus =
        user.isNewUser ? AppStatus.onboardingRequired : AppStatus.authenticated;

    // No conservar navegación pendiente de una cuenta anterior.
    final accountChanged = state.user.id != user.id;

    emit(
      state.copyWith(
        status: nextStatus,
        user: user,
        institutionalProfile: profile,
        clearPendingAnnouncementId: accountChanged,
        clearPendingAcademicTaskId: accountChanged,
        clearPendingClassSession: accountChanged,
      ),
    );

    unawaited(_registerNotificationsForUser(user.id, event.revision));

    _institutionalProfileSubscription = _appUserProfileRepository
        .watchProfile(user.id)
        .listen(
          (profile) {
            add(
              AppInstitutionalProfileChanged(
                profile,
                userId: user.id,
                revision: event.revision,
              ),
            );
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
    if (!state.status.isLoggedIn ||
        event.userId != state.user.id ||
        event.userId != _latestAuthUserId ||
        event.revision != _authRevision) {
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
    await _authRevisionController.close();
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
    if (!state.status.isLoggedIn ||
        event.authRevision != _authRevision ||
        state.pendingAcademicTaskId != event.taskId) {
      return;
    }

    emit(state.copyWith(clearPendingAcademicTaskId: true));
  }

  void _onClassSessionNotificationOpened(
    ClassSessionNotificationOpened event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn ||
        event.sessionId.isEmpty ||
        event.subjectId.isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        pendingClassSessionId: event.sessionId,
        pendingClassSubjectId: event.subjectId,
      ),
    );
  }

  void _onClassSessionNavigationConsumed(
    ClassSessionNavigationConsumed event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn ||
        event.authRevision != _authRevision ||
        state.pendingClassSessionId != event.sessionId ||
        state.pendingClassSubjectId != event.subjectId) {
      return;
    }

    emit(state.copyWith(clearPendingClassSession: true));
  }

  Future<void> _onAppOpened(AppOpened event, Emitter<AppState> emit) async {
    await LocalNotificationService.instance.initialize(
      onNotificationTap: (data) {
        _handleNotificationData(data);
      },
    );

    // Reconcilia recordatorios académicos persistidos con las
    // notificaciones locales sin bloquear el arranque de la app.
    // Restauración académica pendiente de aislamiento por UID.
    // No consultar automáticamente la base SQLite heredada.

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

    if (type == 'class_session') {
      final sessionId = data['session_id']?.toString().trim();
      final subjectId = data['subject_id']?.toString().trim();

      if (sessionId == null ||
          sessionId.isEmpty ||
          subjectId == null ||
          subjectId.isEmpty) {
        Logger().w(
          'Class reminder interaction did not contain '
          'session_id and subject_id.',
        );
        return;
      }

      add(
        ClassSessionNotificationOpened(
          sessionId: sessionId,
          subjectId: subjectId,
        ),
      );
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
      // Firebase Authentication determina la identidad.
      // El almacenamiento local solo restaura preferencias visuales.
      return state.copyWith(isAmoled: json['isAmoled'] as bool? ?? false);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(AppState state) {
    return {'isAmoled': state.isAmoled};
  }
}
