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

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_account_reconciler.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_reconciliation_orchestrator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_startup_account_runner.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_session_cleanup_controller.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends HydratedBloc<AppEvent, AppState> {
  AppBloc({
    required FirebaseMessaging firebaseMessaging,
    required UserRepository userRepository,
    required AppUserProfileRepository appUserProfileRepository,
    required User user,
    AcademicReminderPendingCleanupService? academicCleanupService,
    Future<void> Function(
      void Function(Map<String, dynamic>) onNotificationTap,
    )?
    initializeLocalNotifications,
    Future<void> Function()? configureRemoteMessaging,
    bool enableAcademicStartupReconciliation = false,
    Future<bool> Function(String userId, int authRevision)?
    academicStartupReconciliationOverride,
  }) : _academicCleanupService = academicCleanupService,
       _initializeLocalNotifications = initializeLocalNotifications,
       _configureRemoteMessaging = configureRemoteMessaging,
       _enableAcademicStartupReconciliation =
           enableAcademicStartupReconciliation,
       _academicStartupReconciliationOverride =
           academicStartupReconciliationOverride,
       _firebaseMessaging = firebaseMessaging,
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
    on<ProfilePhotoReviewNotificationOpened>(
      _onProfilePhotoReviewNotificationOpened,
    );
    on<ProfilePhotoReviewNavigationConsumed>(
      _onProfilePhotoReviewNavigationConsumed,
    );
    on<AcademicTaskNotificationOpened>(_onAcademicTaskNotificationOpened);
    on<AcademicTaskNavigationConsumed>(_onAcademicTaskNavigationConsumed);
    on<ClassSessionNotificationOpened>(_onClassSessionNotificationOpened);
    on<ClassSessionNavigationConsumed>(_onClassSessionNavigationConsumed);
    on<ThemeChanged>(_onThemeChanged);
    on<AppUserChanged>(_onUserChanged);
    on<AppProfileRetryRequested>(_onProfileRetryRequested);
    on<AppInstitutionalProfileChanged>(_onInstitutionalProfileChanged);
    on<AppLogoutRequested>(_onLogoutRequested);

    academicReminderCoordinator.updateSession(
      userId: user == User.anonymous ? null : user.id,
      revision: _authRevision,
    );

    _userSubscription = _userRepository.user.listen(_userChanged);

    // Procesar también una sesión restaurada al arrancar.
    // Si el repositorio emite otra sesión, la revisión invalidará
    // automáticamente cualquier resultado anterior.
    if (user != User.anonymous && user.id.trim().isNotEmpty) {
      add(AppUserChanged(user, revision: _authRevision));
    }
  }

  final UserRepository _userRepository;
  final FirebaseMessaging _firebaseMessaging;
  final AppUserProfileRepository _appUserProfileRepository;
  final AcademicReminderPendingCleanupService? _academicCleanupService;
  final Future<void> Function()? _configureRemoteMessaging;
  final bool _enableAcademicStartupReconciliation;
  final Future<bool> Function(String userId, int authRevision)?
  _academicStartupReconciliationOverride;
  bool _academicNotificationsReady = false;
  final Set<(String, int)> _completedStartupReconciliations = {};

  late final AcademicReminderStartupAccountRunner _startupAccountRunner =
      AcademicReminderStartupAccountRunner(
        coordinator: academicReminderCoordinator,
      );

  late final AcademicReminderReconciliationOrchestrator
  _startupReconciliationOrchestrator =
      AcademicReminderReconciliationOrchestrator(
        coordinator: academicReminderCoordinator,
      );
  final Future<void> Function(
    void Function(Map<String, dynamic>) onNotificationTap,
  )?
  _initializeLocalNotifications;

  late final AcademicReminderSessionCleanupController
  _academicCleanupController = AcademicReminderSessionCleanupController(
    coordinator: academicReminderCoordinator,
    cleanupService:
        _academicCleanupService ?? AcademicReminderPendingCleanupService(),
  );

  String _latestAuthUserId;
  User? _retryUser;
  int _authRevision = 0;
  final StreamController<int> _authRevisionController =
      StreamController<int>.broadcast(sync: true);

  final AcademicReminderOperationCoordinator academicReminderCoordinator =
      AcademicReminderOperationCoordinator();

  int get authRevision => _authRevision;

  Stream<int> get authRevisionChanges => _authRevisionController.stream;

  late final StreamSubscription<User> _userSubscription;
  StreamSubscription<AppUserProfile?>? _institutionalProfileSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const _notificationDeviceIdKey =
      'institutional_notification_device_id';

  void _userChanged(User user) {
    // Evitar que una emisión idéntica reinicie una sesión
    // cuyo perfil institucional ya fue validado.
    //
    // No se deduplican sesiones en transición ni usuarios
    // con información diferente.
    if (!isClosed &&
        state.status.isLoggedIn &&
        state.institutionalProfile != null &&
        _latestAuthUserId == user.id &&
        state.user == user) {
      return;
    }

    _latestAuthUserId = user.id;
    _authRevision++;

    academicReminderCoordinator.updateSession(
      userId: user == User.anonymous ? null : user.id,
      revision: _authRevision,
    );

    _authRevisionController.add(_authRevision);

    add(AppUserChanged(user, revision: _authRevision));
  }

  bool _isCurrentAuth(String uid, int revision) =>
      !isClosed &&
      uid.isNotEmpty &&
      _latestAuthUserId == uid &&
      _authRevision == revision;

  Future<void> _requestAcademicStartup() async {
    if (!_enableAcademicStartupReconciliation) {
      await _requestAcademicCleanup();
      return;
    }

    final currentState = state;
    final uid = currentState.user.id.trim();
    final revision = _authRevision;
    final key = (uid, revision);

    if (!_academicNotificationsReady ||
        !currentState.status.isLoggedIn ||
        currentState.institutionalProfile == null ||
        !_isCurrentAuth(uid, revision) ||
        _completedStartupReconciliations.contains(key)) {
      return;
    }

    try {
      final completed = await _startupAccountRunner.run(
        userId: uid,
        authRevision: revision,
        reconcile: (AcademicAccountScope account) {
          final override = _academicStartupReconciliationOverride;
          if (override != null) {
            return override(account.userId, revision);
          }

          return AcademicReminderAccountReconciler.forAccount(
            account: account,
            authRevision: revision,
            coordinator: academicReminderCoordinator,
            orchestrator: _startupReconciliationOrchestrator,
          ).reconcile();
        },
      );

      if (completed && _isCurrentAuth(uid, revision)) {
        _completedStartupReconciliations.add(key);
      }
    } catch (error, stackTrace) {
      // La restauración académica no debe impedir la autenticación.
      // No registrar un éxito: una solicitud posterior puede reintentar.
      Logger().w(
        'No se pudo completar la reconciliación académica inicial.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _requestAcademicCleanup() async {
    final currentState = state;
    final uid = currentState.user.id.trim();
    final revision = _authRevision;

    if (!currentState.status.isLoggedIn ||
        currentState.institutionalProfile == null ||
        !_isCurrentAuth(uid, revision)) {
      return;
    }

    try {
      await _academicCleanupController.request(
        userId: uid,
        authRevision: revision,
        authenticated: true,
      );
    } catch (error, stackTrace) {
      // Un error del plugin no debe impedir iniciar sesión.
      // El controlador permite reintentos posteriores.
      Logger().w(
        'No se pudo completar la limpieza académica de la sesión.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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
        clearPendingPhotoReview: accountChanged,
        clearPendingAcademicTaskId: accountChanged,
        clearPendingClassSession: accountChanged,
      ),
    );

    // La cuenta y su perfil ya fueron validados.
    // La barrera de inicialización evita limpiar antes del plugin.
    unawaited(_requestAcademicStartup());

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
    // Invalidar inmediatamente las operaciones académicas pendientes.
    // No cancela notificaciones ni modifica SQLite.
    _authRevision++;
    _latestAuthUserId = '';
    academicReminderCoordinator.updateSession(
      userId: null,
      revision: _authRevision,
    );

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
    _handleNotificationData(data);
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

  void _onProfilePhotoReviewNotificationOpened(
    ProfilePhotoReviewNotificationOpened event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn ||
        state.institutionalProfile == null ||
        state.user.id != event.userId ||
        !_isCurrentAuth(event.userId, event.authRevision) ||
        (event.decision != 'approved' && event.decision != 'rejected')) {
      return;
    }

    emit(
      state.copyWith(
        pendingPhotoReviewDecision: event.decision,
        pendingPhotoReviewUserId: event.userId,
        pendingPhotoReviewAuthRevision: event.authRevision,
      ),
    );
  }

  void _onProfilePhotoReviewNavigationConsumed(
    ProfilePhotoReviewNavigationConsumed event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn ||
        state.user.id != event.userId ||
        !_isCurrentAuth(event.userId, event.authRevision) ||
        state.pendingPhotoReviewUserId != event.userId ||
        state.pendingPhotoReviewAuthRevision != event.authRevision) {
      return;
    }

    emit(state.copyWith(clearPendingPhotoReview: true));
  }

  void _onAcademicTaskNotificationOpened(
    AcademicTaskNotificationOpened event,
    Emitter<AppState> emit,
  ) {
    if (!state.status.isLoggedIn ||
        event.taskId.isEmpty ||
        state.user.id != event.userId ||
        !_isCurrentAuth(event.userId, event.authRevision)) {
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
        event.subjectId.isEmpty ||
        state.user.id != event.userId ||
        !_isCurrentAuth(event.userId, event.authRevision)) {
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
    final initializer = _initializeLocalNotifications;

    if (initializer == null) {
      await LocalNotificationService.instance.initialize(
        onNotificationTap: _handleNotificationData,
      );
    } else {
      await initializer(_handleNotificationData);
    }

    // Solo se habilita después de inicializar correctamente el plugin.
    _academicCleanupController.markNotificationsReady();
    _academicNotificationsReady = true;

    // Funciona también si la autenticación terminó antes que AppOpened.
    unawaited(_requestAcademicStartup());

    // La reconciliación académica se ejecuta únicamente cuando
    // el interruptor experimental está habilitado.

    // Las pruebas pueden sustituir la configuración remota.
    // En producción se mantienen los listeners FCM originales.
    final configureRemote = _configureRemoteMessaging;
    if (configureRemote != null) {
      await configureRemote();
      return;
    }

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

    // Los recordatorios académicos deben acreditar su propietario.
    // Los payloads heredados sin UID no habilitan navegación automática.
    String? academicOwner;
    int? academicRevision;

    if (type == 'academic_task' || type == 'class_session') {
      academicOwner = data['user_id']?.toString().trim();
      academicRevision = _authRevision;

      if (academicOwner == null ||
          academicOwner.isEmpty ||
          !state.status.isLoggedIn ||
          state.user.id != academicOwner ||
          !_isCurrentAuth(academicOwner, academicRevision)) {
        Logger().w('Academic notification ignored: missing or inactive owner.');
        return;
      }
    }

    if (type == 'academic_task') {
      final taskId = data['task_id']?.toString().trim();

      if (taskId == null || taskId.isEmpty) {
        Logger().w('Academic reminder interaction did not contain a task_id.');
        return;
      }

      add(
        AcademicTaskNotificationOpened(
          taskId,
          userId: academicOwner!,
          authRevision: academicRevision!,
        ),
      );
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
          userId: academicOwner!,
          authRevision: academicRevision!,
        ),
      );
      return;
    }

    if (type == 'profile_photo_review') {
      final owner = data['user_id']?.toString().trim();
      final decision = data['decision']?.toString().trim();

      if (owner == null ||
          owner.isEmpty ||
          (decision != 'approved' && decision != 'rejected') ||
          !state.status.isLoggedIn ||
          state.user.id != owner ||
          !_isCurrentAuth(owner, _authRevision)) {
        Logger().w(
          'Photo review notification ignored: invalid or inactive owner.',
        );
        return;
      }

      add(
        ProfilePhotoReviewNotificationOpened(
          decision: decision!,
          userId: owner,
          authRevision: _authRevision,
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
