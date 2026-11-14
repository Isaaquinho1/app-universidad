import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/announcements/bloc/announcement_bloc.dart';
import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/repositories/repositories.dart';
import 'package:conecta_itt/announcements/view/announcement_feed_view.dart';
import 'package:conecta_itt/feed/widgets/campus_context_hero.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeedRepository implements AnnouncementRepository {
  final requests = <Completer<List<Announcement>>>[];

  @override
  Stream<List<Announcement>> watchAnnouncementsForProfile({
    required AppUserProfile profile,
    int limit = 100,
  }) {
    final request = Completer<List<Announcement>>();
    requests.add(request);

    late final StreamController<List<Announcement>> controller;

    controller = StreamController<List<Announcement>>(
      onListen: () {
        request.future.then((announcements) {
          if (!controller.isClosed && controller.hasListener) {
            controller.add(announcements);
          }
        });
      },
      onCancel: () {
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<Map<String, AnnouncementReceipt>> fetchReceiptsForAnnouncements({
    required Iterable<String> announcementIds,
    required String userUid,
  }) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AssetRepository implements PublicationAssetRepository {
  @override
  Future<Map<String, List<PublicationAsset>>> fetchAssetsForPublications({
    required Iterable<String> publicationIds,
  }) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Announcement> _publications(int count, {bool updated = false}) {
  final date = DateTime(2026, 11, 3);
  return List.generate(
    count,
    (index) => Announcement(
      id: 'publication-$index',
      title: 'Publicación $index${updated ? ' actualizada' : ''}',
      body: 'Información institucional para la comunidad estudiantil.',
      authorUid: 'author',
      target: const AnnouncementTarget.all(),
      status: AnnouncementStatus.published,
      priority: AnnouncementPriority.normal,
      contentType:
          index.isEven
              ? PublicationContentType.news
              : PublicationContentType.announcement,
      createdAt: date,
      updatedAt: date,
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scenario in ['empty', 'short', 'long']) {
      testWidgets(
        '$platform: $scenario feed refresh overlays a stable header',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final notifications = <ScrollNotification>[];
          final repository = _FeedRepository();
          final scrollController = ScrollController();
          final bloc = AnnouncementBloc(
            repository: repository,
            assetRepository: _AssetRepository(),
            profile: const AppUserProfile(
              uid: 'student',
              role: AppUserRole.student,
              active: true,
              profileCompleted: true,
            ),
          )..add(const AnnouncementsStarted());
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await bloc.close();
            scrollController.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: platform,
                extensions: const <ThemeExtension<dynamic>>[AppColors.light],
              ),
              home: Scaffold(
                body: BlocProvider<AnnouncementBloc>.value(
                  value: bloc,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      notifications.add(notification);
                      return false;
                    },
                    child: AnnouncementFeedView(
                      scrollController: scrollController,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final count = switch (scenario) {
            'empty' => 0,
            'short' => 2,
            _ => 12,
          };
          repository.requests.single.complete(_publications(count));
          await tester.pumpAndSettle();
          if (scenario == 'short') {
            await tester.tap(find.text('Noticias'));
            await tester.pumpAndSettle();
            expect(find.byType(AnnouncementCard), findsOneWidget);
          }
          if (scenario == 'long') {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -180),
            );
            await tester.pumpAndSettle();
            expect(scrollController.offset, greaterThan(0));
            scrollController.jumpTo(0);
            await tester.pump();
          } else {
            expect(scrollController.position.maxScrollExtent, 0);
          }
          final hero = find.byType(CampusContextHero);
          final heroTop = tester.getTopLeft(hero).dy;
          final cardTop =
              count == 0
                  ? null
                  : tester.getTopLeft(find.byType(AnnouncementCard).first).dy;
          final viewport = tester.renderObject(
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Viewport),
            ),
          );
          // Use the photo's right side, clear of the title and filter controls.
          final start = tester.getRect(hero).topRight + const Offset(-24, 80);
          expect(
            tester
                .hitTestOnBinding(start)
                .path
                .any((entry) => identical(entry.target, viewport)),
            isTrue,
            reason: 'The pointer must reach the feed viewport.',
          );
          expect(find.byType(RefreshIndicator), findsOneWidget);
          notifications.clear();
          const frame = Duration(milliseconds: 16);
          var eventTime = Duration.zero;
          final gesture = await tester.startGesture(start);
          await tester.pump(frame);
          eventTime += frame;
          await gesture.moveBy(const Offset(0, 20), timeStamp: eventTime);
          await tester.pump(frame);
          // Cross touch slop first, then deliver a drag over multiple frames.
          for (var step = 0; step < 14; step++) {
            eventTime += frame;
            await gesture.moveBy(const Offset(0, 52), timeStamp: eventTime);
            await tester.pump(frame);
          }
          expect(
            notifications.whereType<ScrollStartNotification>().any(
              (notification) =>
                  notification.depth == 0 && notification.dragDetails != null,
            ),
            isTrue,
            reason: 'The scrollable must recognize a user drag at the top.',
          );
          expect(
            notifications.whereType<OverscrollNotification>().any(
              (notification) =>
                  notification.depth == 0 && notification.overscroll < 0,
            ),
            isTrue,
            reason: 'Clamping must emit leading overscroll for refresh.',
          );
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(
            tester
                .widget<RefreshProgressIndicator>(
                  find.byType(RefreshProgressIndicator),
                )
                .value,
            closeTo(0.75, 0.01),
            reason: 'The drag must fully reveal the indicator before release.',
          );
          // Check while the finger is still down: testing only after release
          // could miss iOS bouncing back from a large white gap.
          expect(scrollController.offset, 0);
          expect(tester.getTopLeft(hero).dy, closeTo(heroTop, 0.1));
          if (cardTop != null) {
            expect(
              tester.getTopLeft(find.byType(AnnouncementCard).first).dy,
              closeTo(cardTop, 0.1),
            );
          }
          eventTime += frame;
          await gesture.up(timeStamp: eventTime);
          // Let snap/release animation and the Bloc event queue advance. Do not
          // pumpAndSettle while the held request keeps the spinner animating.
          // Advance both widget frames and asynchronous event processing.
          // The second request is the completion condition.
          for (
            var tick = 0;
            tick < 30 && repository.requests.length < 2;
            tick++
          ) {
            await tester.pump(frame);
            await tester.runAsync(() async {
              await Future<void>.delayed(Duration.zero);
            });
            await tester.pump();
          }
          expect(repository.requests, hasLength(2));
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(find.byType(CupertinoActivityIndicator), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          // The request is deliberately held longer than the reveal animation.
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(tester.getTopLeft(hero).dy, closeTo(heroTop, 0.1));
          if (count > 0) {
            expect(find.text('Publicación 0'), findsOneWidget);
          }
          repository.requests.last.complete(
            _publications(count, updated: true),
          );
          await tester.pumpAndSettle();
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          expect(tester.getTopLeft(hero).dy, closeTo(heroTop, 0.1));
          if (count > 0) {
            expect(find.text('Publicación 0 actualizada'), findsOneWidget);
          }
          if (scenario == 'short') {
            final cards = tester.widgetList<AnnouncementCard>(
              find.byType(AnnouncementCard),
            );
            expect(cards, hasLength(1));
            expect(cards.single.announcement.isNews, isTrue);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
