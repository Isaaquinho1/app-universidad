import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:logger/logger.dart';
import 'package:rtu_mirea_app/app/theme/theme_mode.dart';
import 'package:rtu_mirea_app/institutional_profile/institutional_profile.dart';
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

  void _userChanged(User user) => add(AppUserChanged(user));

  Future<void> _onUserChanged(
    AppUserChanged event,
    Emitter<AppState> emit,
  ) async {
    final user = event.user;

    await _institutionalProfileSubscription?.cancel();
    _institutionalProfileSubscription = null;

    if (user == User.anonymous) {
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

  Future<void> _onRecieveInteractedMessage(
    RecieveInteractedMessage event,
    Emitter<AppState> _,
  ) async {
    final data = event.message.data;
    Logger().i('Handling message: $data');
  }

  Future<void> _onAppOpened(AppOpened event, Emitter<AppState> emit) async {
    await setupInteractedMessage(emit);
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
