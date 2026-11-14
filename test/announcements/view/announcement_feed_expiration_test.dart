import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:conecta_itt/announcements/bloc/announcement_bloc.dart';
import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/repositories/repositories.dart';
import 'package:conecta_itt/announcements/view/announcement_feed_view.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExpirationRepository implements AnnouncementRepository {
  final controller = StreamController<List<Announcement>>();

  @override
  Stream<List<Announcement>> watchAnnouncementsForProfile({
    required AppUserProfile profile,
    int limit = 100,
  }) => controller.stream;

  @override
  Future<Map<String, AnnouncementReceipt>> fetchReceiptsForAnnouncements({
    required Iterable<String> announcementIds,
    required String userUid,
  }) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExpirationAssets implements PublicationAssetRepository {
  @override
  Future<Map<String, List<PublicationAsset>>> fetchAssetsForPublications({
    required Iterable<String> publicationIds,
  }) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Announcement _publication({
  required String id,
  required String title,
  required PublicationContentType contentType,
  required DateTime now,
  required Duration lifetime,
}) {
  return Announcement(
    id: id,
    title: title,
    body: 'Contenido institucional de prueba.',
    authorUid: 'admin',
    target: const AnnouncementTarget.all(),
    status: AnnouncementStatus.published,
    priority: AnnouncementPriority.normal,
    contentType: contentType,
    createdAt: now,
    updatedAt: now,
    publishedAt: now,
    expiresAt: now.add(lifetime),
  );
}

void main() {
  testWidgets('El feed oculta vencimientos consecutivos sin refrescar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ExpirationRepository();

    final bloc = AnnouncementBloc(
      repository: repository,
      assetRepository: _ExpirationAssets(),
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
      await repository.controller.close();
    });

    await withClock(tester.binding.clock, () async {
      final now = clock.now();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: Scaffold(
            body: BlocProvider<AnnouncementBloc>.value(
              value: bloc,
              child: const AnnouncementFeedView(),
            ),
          ),
        ),
      );

      await tester.pump();

      repository.controller.add([
        _publication(
          id: 'news-expiration',
          title: 'Noticia vigente de prueba',
          contentType: PublicationContentType.news,
          now: now,
          lifetime: const Duration(seconds: 30),
        ),
        _publication(
          id: 'announcement-expiration',
          title: 'Comunicado vigente de prueba',
          contentType: PublicationContentType.announcement,
          now: now,
          lifetime: const Duration(seconds: 60),
        ),
      ]);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('Noticia vigente de prueba'), findsOneWidget);
      expect(find.text('Comunicado vigente de prueba'), findsOneWidget);

      // Todavía no ha vencido ninguna publicación.
      await tester.pump(const Duration(seconds: 29));

      expect(find.text('Noticia vigente de prueba'), findsOneWidget);
      expect(find.text('Comunicado vigente de prueba'), findsOneWidget);

      // Se supera el primer vencimiento.
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Noticia vigente de prueba'), findsNothing);
      expect(find.text('Comunicado vigente de prueba'), findsOneWidget);

      // El comunicado sigue vigente.
      await tester.pump(const Duration(seconds: 28));

      expect(find.text('Comunicado vigente de prueba'), findsOneWidget);

      // Se supera el segundo vencimiento.
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Comunicado vigente de prueba'), findsNothing);

      // El BLoC conserva los datos originales.
      expect(bloc.state.announcements, hasLength(2));
    });
  });

  testWidgets('El feed programa vencimientos con el Bloc ya cargado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ExpirationRepository();

    final bloc = AnnouncementBloc(
      repository: repository,
      assetRepository: _ExpirationAssets(),
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
      await repository.controller.close();
    });

    await withClock(tester.binding.clock, () async {
      final now = clock.now();

      // Inicializar Flutter sin montar todavía el feed.
      await tester.pumpWidget(const SizedBox.shrink());

      for (var i = 0; i < 10; i++) {
        if (repository.controller.hasListener) break;
        await tester.pump();
      }

      expect(
        repository.controller.hasListener,
        isTrue,
        reason: 'El Bloc debe estar suscrito antes de emitir datos.',
      );

      repository.controller.add([
        _publication(
          id: 'previously-loaded',
          title: 'Noticia precargada',
          contentType: PublicationContentType.news,
          now: now,
          lifetime: const Duration(seconds: 20),
        ),
      ]);

      for (var i = 0; i < 12; i++) {
        if (bloc.state.status == AnnouncementsStatus.populated) {
          break;
        }
        await tester.pump();
      }

      expect(bloc.state.status, AnnouncementsStatus.populated);
      expect(bloc.state.announcements, hasLength(1));

      // El feed se monta cuando el Bloc YA tiene publicaciones.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: Scaffold(
            body: BlocProvider<AnnouncementBloc>.value(
              value: bloc,
              child: const AnnouncementFeedView(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Noticia precargada'), findsOneWidget);

      // El temporizador debe conservar la publicación
      // hasta antes de su vencimiento.
      await tester.pump(const Duration(seconds: 19));

      expect(find.text('Noticia precargada'), findsOneWidget);

      // Al vencer, debe desaparecer sin nuevos eventos del Bloc.
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Noticia precargada'), findsNothing);

      // La publicación permanece en el estado del Bloc.
      expect(bloc.state.announcements, hasLength(1));
    });
  });

  testWidgets('El feed reevalua vencimientos al regresar a primer plano', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ExpirationRepository();

    final bloc = AnnouncementBloc(
      repository: repository,
      assetRepository: _ExpirationAssets(),
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
      await repository.controller.close();
    });

    var logicalNow = tester.binding.clock.now();

    await withClock(Clock(() => logicalNow), () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: Scaffold(
            body: BlocProvider<AnnouncementBloc>.value(
              value: bloc,
              child: const AnnouncementFeedView(),
            ),
          ),
        ),
      );

      for (var i = 0; i < 12; i++) {
        if (repository.controller.hasListener) break;
        await tester.pump();
      }

      expect(repository.controller.hasListener, isTrue);

      repository.controller.add([
        _publication(
          id: 'resume-expiration',
          title: 'Noticia que vence en segundo plano',
          contentType: PublicationContentType.news,
          now: logicalNow,
          lifetime: const Duration(seconds: 20),
        ),
      ]);

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));

        if (bloc.state.status == AnnouncementsStatus.populated) {
          break;
        }
      }

      await tester.pump();

      expect(find.text('Noticia que vence en segundo plano'), findsOneWidget);

      expect(bloc.state.announcements, hasLength(1));

      // Simulamos que transcurre el tiempo mientras la app
      // no recibe fotogramas ni eventos del repositorio.
      logicalNow = logicalNow.add(const Duration(seconds: 21));

      expect(bloc.state.announcements, hasLength(1));

      // Flutter notifica que la aplicacion regresa a primer plano.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Allow immediate timers triggered by the campus weather refresh
      // to complete before the widget test verifies pending timers.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(find.text('Noticia que vence en segundo plano'), findsNothing);

      // La reevaluacion no debe borrar datos del Bloc.
      expect(bloc.state.announcements, hasLength(1));
    });
  });

  testWidgets('El feed cancela el vencimiento al desmontarse', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ExpirationRepository();

    final bloc = AnnouncementBloc(
      repository: repository,
      assetRepository: _ExpirationAssets(),
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
      await repository.controller.close();
    });

    await withClock(tester.binding.clock, () async {
      final now = clock.now();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: Scaffold(
            body: BlocProvider<AnnouncementBloc>.value(
              value: bloc,
              child: const AnnouncementFeedView(),
            ),
          ),
        ),
      );

      for (var i = 0; i < 12; i++) {
        if (repository.controller.hasListener) break;
        await tester.pump();
      }

      expect(repository.controller.hasListener, isTrue);

      repository.controller.add([
        _publication(
          id: 'dispose-expiration',
          title: 'Noticia pendiente de vencimiento',
          contentType: PublicationContentType.news,
          now: now,
          lifetime: const Duration(seconds: 20),
        ),
      ]);

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));

        if (bloc.state.status == AnnouncementsStatus.populated) {
          break;
        }
      }

      await tester.pump();

      expect(find.text('Noticia pendiente de vencimiento'), findsOneWidget);

      // Abandonar el feed antes del vencimiento.
      await tester.pumpWidget(const SizedBox.shrink());

      expect(find.byType(AnnouncementFeedView), findsNothing);

      // Avanzar el reloj más allá de la fecha de vencimiento.
      await tester.pump(const Duration(seconds: 25));
      await tester.pump();

      // No debe producirse una excepción tras desmontar la pantalla.
      expect(tester.takeException(), isNull);

      // Desmontar la vista no debe eliminar los datos del Bloc.
      expect(bloc.state.announcements, hasLength(1));
    });
  });
}
