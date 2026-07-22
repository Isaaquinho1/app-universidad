import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';
import 'package:rtu_mirea_app/home/view/home_page.dart';
import 'package:rtu_mirea_app/map/view/map_page_view.dart';
import 'package:rtu_mirea_app/profile/profile.dart';
import 'package:rtu_mirea_app/profile/view/notifications_settings_page.dart';
import 'package:rtu_mirea_app/navigation/view/scaffold_navigation_shell.dart';
import 'package:rtu_mirea_app/feed/feed.dart';
import 'package:rtu_mirea_app/onboarding/view/onboarding_page.dart';
import 'package:rtu_mirea_app/profile/view/profile_settings_page.dart';

import 'package:rtu_mirea_app/services/view/view.dart';
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
        TypedGoRoute<ServicesRoute>(
          path: '/services',
          routes: <TypedRoute<RouteData>>[TypedGoRoute<MapRoute>(path: 'map')],
        ),
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
            TypedGoRoute<AboutAppRoute>(path: 'about'),
            TypedGoRoute<ProfileSettingsRoute>(
              path: 'settings',
              routes: <TypedRoute<RouteData>>[
                TypedGoRoute<NotificationsSettingsRoute>(path: 'notifications'),
              ],
            ),
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

class MapRoute extends GoRouteData {
  const MapRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const MapPageView();
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

class NotificationsSettingsRoute extends GoRouteData {
  const NotificationsSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const NotificationsSettingsPage();
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
