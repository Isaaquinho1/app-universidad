import 'dart:async';

import 'package:conecta_itt/main/bootstrap/startup_app.dart';
import 'package:conecta_itt/splash/view/institutional_splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'prepares splash assets before releasing native or starting scope',
    (tester) async {
      final assetsReady = Completer<void>();
      final applicationReady = Completer<Widget>();
      var releases = 0;
      var initializations = 0;
      await tester.pumpWidget(
        StartupApp(
          prepareSplash: (_) => assetsReady.future,
          onSplashReady: () => releases++,
          initialize: () {
            initializations++;
            return applicationReady.future;
          },
          onError: (error, stack) => fail('Unexpected error: $error'),
        ),
      );
      await tester.pump();
      expect(releases, 0);
      expect(initializations, 0);
      assetsReady.complete();
      await tester.pump();
      await tester.pump();
      expect(releases, 1);
      expect(initializations, 1);
      applicationReady.complete(const MaterialApp(home: Text('Ready')));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(releases, 1);
    },
  );

  testWidgets('shows Flutter splash during one real initialization', (
    tester,
  ) async {
    final ready = Completer<Widget>();
    var attempts = 0;
    Widget startup() => StartupApp(
      prepareSplash: (_) async {},
      initialize: () {
        attempts++;
        return ready.future;
      },
      onError: (error, stack) => fail('Unexpected startup error: $error'),
    );

    await tester.pumpWidget(startup());
    expect(find.byType(InstitutionalSplashPage), findsOneWidget);
    await tester.pump();
    expect(attempts, 1);

    await tester.pumpWidget(startup());
    expect(attempts, 1);
    ready.complete(const MaterialApp(home: Text('Application ready')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Application ready'), findsOneWidget);
    expect(find.byType(InstitutionalSplashPage), findsNothing);
    expect(attempts, 1);
  });

  testWidgets('failed startup reports error and retries only on request', (
    tester,
  ) async {
    final first = Completer<Widget>();
    final retry = Completer<Widget>();
    final errors = <Object>[];
    var attempts = 0;

    await tester.pumpWidget(
      StartupApp(
        prepareSplash: (_) async {},
        initialize: () => ++attempts == 1 ? first.future : retry.future,
        onError: (error, stack) => errors.add(error),
      ),
    );
    await tester.pump();
    first.completeError(StateError('Initialization unavailable'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No se pudo iniciar Conecta ITT.'), findsOneWidget);
    expect(attempts, 1);
    expect(errors, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(InstitutionalSplashPage), findsOneWidget);
    expect(attempts, 2);
    retry.complete(const MaterialApp(home: Text('Recovered')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Recovered'), findsOneWidget);
  });
}
