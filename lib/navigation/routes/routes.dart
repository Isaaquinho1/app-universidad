import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/home/view/home_page.dart';
import 'package:conecta_itt/profile/profile.dart';
import 'package:conecta_itt/navigation/view/scaffold_navigation_shell.dart';
import 'package:conecta_itt/feed/feed.dart';
import 'package:conecta_itt/onboarding/view/onboarding_page.dart';
import 'package:conecta_itt/welcome/welcome.dart';
import 'package:conecta_itt/profile/view/profile_settings_page.dart';
import 'package:conecta_itt/profile/view/profile_edit_page.dart';

import 'package:conecta_itt/services/view/view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/home')
class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

@TypedGoRoute<OnboardingRoute>(path: '/onboarding')
class OnboardingRoute extends GoRouteData {
  const OnboardingRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OnBoardingPage();
}

@TypedGoRoute<WelcomeRoute>(path: '/welcome')
class WelcomeRoute extends GoRouteData {
  const WelcomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const WelcomePage();
}

@TypedStatefulShellRoute<ShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<FeedBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<FeedRoute>(
          path: '/feed',
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<AnnouncementDetailRoute>(
              path: 'announcement/:announcementId',
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<ServicesBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ServicesRoute>(path: '/services'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(
          path: '/profile',
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<AdminAnnouncementManagementRoute>(
              path: 'announcement-management',
              routes: <TypedRoute<RouteData>>[
                TypedGoRoute<AdminAnnouncementCreateRoute>(path: 'create'),
                TypedGoRoute<AdminAnnouncementEditRoute>(
                  path: ':announcementId/edit',
                ),
                TypedGoRoute<AdminAnnouncementResultsRoute>(
                  path: ':announcementId/results',
                ),
              ],
            ),
            TypedGoRoute<ProfileEditRoute>(path: 'edit'),
            TypedGoRoute<AboutAppRoute>(path: 'about'),
            TypedGoRoute<ProfileSettingsRoute>(path: 'settings'),
          ],
        ),
      ],
    ),
  ],
)
class ShellRouteData extends StatefulShellRouteData {
  const ShellRouteData();
  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return ScaffoldNavigationShell(navigationShell: navigationShell);
  }
}

class FeedBranchData extends StatefulShellBranchData {
  const FeedBranchData();
}

class ServicesBranchData extends StatefulShellBranchData {
  const ServicesBranchData();
}

class ProfileBranchData extends StatefulShellBranchData {
  const ProfileBranchData();
}

class FeedRoute extends GoRouteData {
  const FeedRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const FeedView();
  }
}

class AnnouncementDetailRoute extends GoRouteData {
  const AnnouncementDetailRoute({required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AnnouncementDetailPage(announcementId: announcementId);
  }
}

class ServicesRoute extends GoRouteData {
  const ServicesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ServicesPage();
  }
}

class ProfileRoute extends GoRouteData {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProfilePage();
  }
}

class AdminAnnouncementManagementRoute extends GoRouteData {
  const AdminAnnouncementManagementRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AdminAnnouncementManagementPage();
  }
}

class AdminAnnouncementCreateRoute extends GoRouteData {
  const AdminAnnouncementCreateRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AdminAnnouncementCreatePage();
  }
}

class AdminAnnouncementEditRoute extends GoRouteData {
  const AdminAnnouncementEditRoute({required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AdminAnnouncementEditPage(announcementId: announcementId);
  }
}

class AdminAnnouncementResultsRoute extends GoRouteData {
  const AdminAnnouncementResultsRoute({required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AdminAnnouncementResultsPage(announcementId: announcementId);
  }
}

class ProfileEditRoute extends GoRouteData {
  const ProfileEditRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProfileEditPage();
  }
}

class AboutAppRoute extends GoRouteData {
  const AboutAppRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AboutAppPage();
  }
}

class ProfileSettingsRoute extends GoRouteData {
  const ProfileSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProfileSettingsPage();
  }
}

GoRouter createRouter() => GoRouter(
  routes: $appRoutes,
  initialLocation: '/home',
  debugLogDiagnostics: kDebugMode,
  observers: [
    FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    SentryNavigatorObserver(
      autoFinishAfter: const Duration(seconds: 5),
      setRouteNameAsTransaction: true,
    ),
  ],
);
