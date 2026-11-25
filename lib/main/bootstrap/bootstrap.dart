import 'dart:async';

import 'package:conecta_itt/main/bootstrap/startup_app.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef AppBuilder = Future<Widget> Function(void _);

Future<void> bootstrap(AppBuilder builder) async {
  await runZonedGuarded<Future<void>>(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      binding.deferFirstFrame();

      Widget wrapWithSentry(Widget child) {
        return SentryScreenshotWidget(
          child: DefaultAssetBundle(bundle: SentryAssetBundle(), child: child),
        );
      }

      runApp(
        wrapWithSentry(
          StartupApp(
            initialize: () => builder(null),
            onSplashReady: binding.allowFirstFrame,
            onError: (error, stackTrace) {
              Logger().e(
                'Startup failed',
                error: error,
                stackTrace: stackTrace,
              );
              unawaited(Sentry.captureException(error, stackTrace: stackTrace));
            },
          ),
        ),
      );
    },
    (error, stackTrace) {
      Logger().e('Unhandled error', error: error, stackTrace: stackTrace);
      Sentry.captureException(error, stackTrace: stackTrace);
    },
  );
}
