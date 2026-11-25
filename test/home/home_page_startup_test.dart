import 'package:conecta_itt/app/bloc/app_bloc.dart';
import 'package:conecta_itt/home/view/home_page.dart';
import 'package:conecta_itt/splash/view/institutional_splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class _Storage implements Storage {
  _Storage({required this.onboardingShown});
  final bool onboardingShown;

  @override
  dynamic read(String key) => {
    'settings': {'onboardingShown': onboardingShown},
  };
  @override
  Future<void> write(String key, dynamic value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> close() async {}
}

class _AppBloc extends Cubit<AppState> implements AppBloc {
  _AppBloc(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<GoRouter> showHome(
    WidgetTester tester, {
    required bool onboardingShown,
    required AppState state,
    bool notificationRace = false,
  }) async {
    HydratedBloc.storage = _Storage(onboardingShown: onboardingShown);
    final bloc = _AppBloc(state);
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder:
              (_, _) =>
                  notificationRace
                      ? _NotificationRace(router: router)
                      : const HomePage(),
        ),
        for (final path in [
          '/onboarding',
          '/welcome',
          '/feed',
          '/announcement',
        ])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await bloc.close();
    });
    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    expect(find.byType(InstitutionalSplashPage), findsOneWidget);
    return router;
  }

  for (final scenario in [
    (onboarding: false, authenticated: false, route: '/onboarding'),
    (onboarding: true, authenticated: false, route: '/welcome'),
    (onboarding: true, authenticated: true, route: '/feed'),
  ]) {
    testWidgets('startup resolves ${scenario.route}', (tester) async {
      final router = await showHome(
        tester,
        onboardingShown: scenario.onboarding,
        state:
            scenario.authenticated
                ? const AppState(status: AppStatus.authenticated)
                : const AppState.unauthenticated(),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(router.routeInformationProvider.value.uri.path, scenario.route);
      expect(find.text(scenario.route), findsOneWidget);
    });
  }

  testWidgets('notification destination wins over scheduled home redirect', (
    tester,
  ) async {
    final router = await showHome(
      tester,
      onboardingShown: true,
      state: const AppState(status: AppStatus.authenticated),
      notificationRace: true,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(router.routeInformationProvider.value.uri.path, '/announcement');
    expect(find.text('/announcement'), findsOneWidget);
  });
}

class _NotificationRace extends StatefulWidget {
  const _NotificationRace({required this.router});
  final GoRouter router;

  @override
  State<_NotificationRace> createState() => _NotificationRaceState();
}

class _NotificationRaceState extends State<_NotificationRace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.router.go('/announcement');
      });
    });
  }

  @override
  Widget build(BuildContext context) => const HomePage();
}
