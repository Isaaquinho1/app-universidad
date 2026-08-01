import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/navigation/navigation.dart';
import 'package:flutter/services.dart';
import 'package:conecta_itt/analytics/bloc/analytics_bloc.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:conecta_itt/home/cubit/home_cubit.dart';
import 'package:conecta_itt/l10n/l10n.dart';
import 'package:app_ui/app_ui.dart';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:user_repository/user_repository.dart';
import 'package:conecta_itt/di/app_scope.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';

class App extends StatelessWidget {
  const App({super.key, required User user}) : _user = user;

  final User _user;

  @override
  Widget build(BuildContext context) {
    return ScopeBuilder<AppScopeContainer>.withPlaceholder(
      builder: (context, appScope) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: appScope.analyticsRepository),
            RepositoryProvider.value(value: appScope.userRepository),
            RepositoryProvider<AppUserProfileRepository>.value(
              value: appScope.appUserProfileRepository,
            ),
            RepositoryProvider<AcademicCatalogRepository>.value(
              value: appScope.academicCatalogRepository,
            ),
            RepositoryProvider<StudentProfilePhotoRepository>.value(
              value: appScope.studentProfilePhotoRepository,
            ),
            RepositoryProvider<AdminProfilePhotoRepository>.value(
              value: appScope.adminProfilePhotoRepository,
            ),
            RepositoryProvider<AnnouncementRepository>.value(
              value: appScope.announcementRepository,
            ),
            RepositoryProvider<PublicationAssetRepository>.value(
              value: appScope.publicationAssetRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => HomeCubit()),

              BlocProvider(
                create:
                    (_) => AppBloc(
                      firebaseMessaging: FirebaseMessaging.instance,
                      userRepository: appScope.userRepository,
                      appUserProfileRepository:
                          appScope.appUserProfileRepository,
                      user: _user,
                    )..add(const AppOpened()),
              ),
              BlocProvider(
                create:
                    (_) => AnalyticsBloc(
                      analyticsRepository: appScope.analyticsRepository,
                    ),
                lazy: false,
              ),
            ],
            child: _AppView(),
          ),
        );
      },
      placeholder: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return Builder(
          builder: (context) {
            final lightTheme = AppTheme.lightTheme;
            final darkTheme = AppTheme.darkTheme;

            return PlatformProvider(
              builder:
                  (context) => AdaptiveTheme(
                    light: lightTheme,
                    dark: darkTheme,
                    initial: AdaptiveThemeMode.dark,
                    builder: (theme, darkTheme) {
                      _configureSystemUI(theme);

                      return PlatformTheme(
                        themeMode:
                            theme.brightness == Brightness.light
                                ? ThemeMode.light
                                : ThemeMode.dark,
                        materialLightTheme: lightTheme,
                        materialDarkTheme: darkTheme,
                        cupertinoLightTheme: MaterialBasedCupertinoThemeData(
                          materialTheme: lightTheme,
                        ),
                        cupertinoDarkTheme: MaterialBasedCupertinoThemeData(
                          materialTheme: darkTheme,
                        ),
                        builder: (context) {
                          final app = PlatformApp.router(
                            restorationScopeId: 'app',
                            localizationsDelegates: [
                              AppLocalizations.delegate,
                              GlobalMaterialLocalizations.delegate,
                              GlobalWidgetsLocalizations.delegate,
                              GlobalCupertinoLocalizations.delegate,
                              SfGlobalLocalizations.delegate,
                            ],
                            supportedLocales: const [
                              Locale('en'),
                              Locale('es'),
                            ],
                            localeResolutionCallback: (
                              deviceLocale,
                              supportedLocales,
                            ) {
                              return const Locale('es');
                            },
                            debugShowCheckedModeBanner: false,
                            title: 'Conecta ITT',
                            routerConfig: _router,
                            builder:
                                (context, child) => Theme(
                                  data: theme,
                                  child: ResponsiveBreakpoints.builder(
                                    child: child!,
                                    breakpoints: const [
                                      Breakpoint(
                                        start: 0,
                                        end: 450,
                                        name: MOBILE,
                                      ),
                                      Breakpoint(
                                        start: 451,
                                        end: 800,
                                        name: TABLET,
                                      ),
                                      Breakpoint(
                                        start: 801,
                                        end: 1920,
                                        name: DESKTOP,
                                      ),
                                      Breakpoint(
                                        start: 1921,
                                        end: double.infinity,
                                        name: '4K',
                                      ),
                                    ],
                                  ),
                                ),
                          );

                          return BlocListener<AppBloc, AppState>(
                            listenWhen:
                                (previous, current) =>
                                    previous.status != current.status,
                            listener: (context, state) {
                              if (!state.status.isLoggedIn) {
                                _router.go('/welcome');
                              }
                            },
                            child: FirebaseInteractedMessageListener(
                              router: _router,
                              child: app,
                            ),
                          );
                        },
                      );
                    },
                  ),
            );
          },
        );
      },
    );
  }

  /// Hide status bar background and set transparent navigation bar while keeping top overlay visible.
  void _configureSystemUI(ThemeData theme) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness:
            theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
        systemNavigationBarIconBrightness:
            theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
      ),
    );
  }
}
