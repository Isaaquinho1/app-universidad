import 'dart:async';

import 'package:conecta_itt/feed/models/campus_weather.dart';
import 'package:conecta_itt/feed/services/campus_weather_service.dart';
import 'package:conecta_itt/feed/widgets/campus_context_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _WeatherService extends CampusWeatherService {
  _WeatherService({CampusWeather? weather, Future<CampusWeather?>? response})
    : _response = response ?? Future.value(weather);

  final Future<CampusWeather?> _response;
  final requests = <bool>[];

  @override
  Future<CampusWeather?> getCurrentWeather({bool forceRefresh = false}) {
    requests.add(forceRefresh);
    return _response;
  }
}

CampusWeather _weather({
  int code = 0,
  double cloud = 10,
  double rain = 0,
  double temperature = 22,
}) => CampusWeather(
  temperatureCelsius: temperature,
  dailyHighCelsius: 25,
  weatherCode: code,
  isDay: true,
  precipitationMillimeters: rain,
  cloudCoverPercent: cloud,
  fetchedAt: DateTime.utc(2026, 11, 24, 18),
);

DateTime _campusHour(int hour) => DateTime.utc(2026, 11, 24, hour + 6);

Widget _app({
  required _WeatherService service,
  required DateTime Function() now,
  double width = 393,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
  int refreshToken = 0,
  EdgeInsets safePadding = const EdgeInsets.only(top: 59),
}) => MaterialApp(
  theme: ThemeData(brightness: brightness, platform: platform),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 900),
      padding: safePadding,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: CampusContextHero(
          now: now,
          weatherService: service,
          refreshToken: refreshToken,
        ),
      ),
    ),
  ),
);

Future<void> _showHero(
  WidgetTester tester, {
  required _WeatherService service,
  required DateTime Function() now,
  double width = 393,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
  EdgeInsets safePadding = const EdgeInsets.only(top: 59),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    _app(
      service: service,
      now: now,
      width: width,
      scale: scale,
      brightness: brightness,
      platform: platform,
      safePadding: safePadding,
    ),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}

void _expectReadableTextRegion(WidgetTester tester, {required bool lightText}) {
  final hero = tester.getRect(find.byType(CampusContextHero));
  final decoration =
      tester
              .widget<DecoratedBox>(
                find.byKey(const ValueKey('campus-hero-scrim')),
              )
              .decoration
          as BoxDecoration;
  final gradient = decoration.gradient! as LinearGradient;
  final protectedRight = hero.left + hero.width * gradient.stops![1];
  // Even the opposite extreme of the photo must retain AA text contrast.
  final worstPhoto = lightText ? Colors.white : Colors.black;
  final protectedBackground = Color.alphaBlend(gradient.colors[1], worstPhoto);
  final textFinders = [
    find.text('CONECTA ITT'),
    find.text('Publicaciones'),
    find.byKey(const ValueKey('campus-hero-message')),
  ];
  for (final finder in textFinders) {
    final text = tester.widget<Text>(finder);
    final bounds = tester.getRect(finder);
    expect(
      _contrast(text.style!.color!, protectedBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(bounds.right, lessThanOrEqualTo(protectedRight + 0.1));
    expect(bounds.bottom, lessThanOrEqualTo(hero.bottom - 32 + 0.1));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
  }
}

void main() {
  final scenes = [
    (
      name: 'madrugada',
      hour: 2,
      asset: 'campus_madrugada.png',
      light: true,
      weather: _weather(),
    ),
    (
      name: 'amanecer',
      hour: 7,
      asset: 'campus_amanecer.png',
      light: false,
      weather: _weather(),
    ),
    (
      name: 'mediodía',
      hour: 12,
      asset: 'campus_medio_dia.png',
      light: false,
      weather: _weather(),
    ),
    (
      name: 'tarde',
      hour: 15,
      asset: 'campus_tarde.png',
      light: false,
      weather: _weather(),
    ),
    (
      name: 'atardecer',
      hour: 19,
      asset: 'campus_casi_noche.png',
      light: true,
      weather: _weather(),
    ),
    (
      name: 'noche',
      hour: 22,
      asset: 'campus_noche.png',
      light: true,
      weather: _weather(),
    ),
    (
      name: 'mañana nublada',
      hour: 9,
      asset: 'campus_nublado.png',
      light: false,
      weather: _weather(cloud: 90),
    ),
    (
      name: 'tarde muy nublada',
      hour: 15,
      asset: 'campus_super_nublado.png',
      light: false,
      weather: _weather(cloud: 95),
    ),
    (
      name: 'lluvia intensa',
      hour: 15,
      asset: 'campus_lloviendo.png',
      light: true,
      weather: _weather(code: 65, rain: 4),
    ),
    (
      name: 'neblina al anochecer',
      hour: 18,
      asset: 'campus_neblina_casi_noche.png',
      light: true,
      weather: _weather(code: 45, cloud: 60),
    ),
  ];

  for (final scene in scenes) {
    testWidgets(
      '${scene.name}: preserves photo and adaptive readable palette',
      (tester) async {
        for (final brightness in Brightness.values) {
          final service = _WeatherService(weather: scene.weather);
          await _showHero(
            tester,
            service: service,
            now: () => _campusHour(scene.hour),
            brightness: brightness,
          );
          final image = tester.widget<Image>(find.byType(Image));
          expect(
            (image.image as AssetImage).assetName,
            'assets/campus/${scene.asset}',
          );
          expect(image.fit, BoxFit.cover);
          final title = tester.widget<Text>(find.text('Publicaciones'));
          expect(
            title.style!.color,
            scene.light ? Colors.white : const Color(0xFF111827),
          );
          _expectReadableTextRegion(tester, lightText: scene.light);
          expect(service.requests, [false]);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('groups the hierarchy at the upper left below the safe area', (
    tester,
  ) async {
    await _showHero(
      tester,
      service: _WeatherService(weather: _weather()),
      now: () => _campusHour(12),
      // Leave enough width for the test renderer's wide Ahem glyphs, so this
      // also checks that short content retains the original minimum height.
      width: 600,
    );
    final label = tester.getRect(find.text('CONECTA ITT'));
    final title = tester.getRect(find.text('Publicaciones'));
    final summary = tester.getRect(
      find.byKey(const ValueKey('campus-hero-message')),
    );
    expect(label.top, closeTo(59 + 14, 0.1));
    expect(title.left, closeTo(label.left, 0.1));
    expect(summary.left, closeTo(label.left, 0.1));
    expect(title.top - label.bottom, closeTo(7, 0.1));
    expect(summary.top - title.bottom, closeTo(8, 0.1));
    expect(tester.getSize(find.byType(CampusContextHero)).height, 238);
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(
      clip.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(30)),
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets(
          '$platform width $width scale $scale: grows without clipping dynamic text',
          (tester) async {
            final weather = _weather(code: 65, rain: 4, temperature: 6);
            final now = DateTime.utc(2026, 11, 28, 21); // Saturday 15:00 CDMX.
            await _showHero(
              tester,
              service: _WeatherService(weather: weather),
              now: () => now,
              width: width,
              scale: scale,
              platform: platform,
            );
            expect(find.text(weather.contextualSummary(now)), findsOneWidget);
            expect(
              tester.getSize(find.byType(CampusContextHero)).height,
              greaterThanOrEqualTo(238),
            );
            if (scale > 1) {
              expect(
                tester.getSize(find.byType(CampusContextHero)).height,
                greaterThan(238),
              );
            }
            _expectReadableTextRegion(tester, lightText: true);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('horizontal safe insets keep large text inside the photograph', (
    tester,
  ) async {
    await _showHero(
      tester,
      service: _WeatherService(weather: _weather()),
      now: () => _campusHour(12),
      width: 320,
      scale: 2,
      safePadding: const EdgeInsets.fromLTRB(34, 59, 21, 0),
    );
    final label = tester.getRect(find.text('CONECTA ITT'));
    final message = tester.getRect(
      find.byKey(const ValueKey('campus-hero-message')),
    );
    expect(label.left, greaterThanOrEqualTo(34 + 16));
    expect(message.right, lessThanOrEqualTo(320 - 21 - 16));
    _expectReadableTextRegion(tester, lightText: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekend loading and no-data messages do not invent weather', (
    tester,
  ) async {
    final result = Completer<CampusWeather?>();
    final now = DateTime.utc(2026, 11, 29, 18); // Sunday noon CDMX.
    final service = _WeatherService(response: result.future);
    await _showHero(tester, service: service, now: () => now);
    expect(
      find.text(CampusWeather.unavailableSummary(now, isLoading: true)),
      findsOneWidget,
    );
    result.complete(null);
    await tester.pumpAndSettle();
    expect(find.text(CampusWeather.unavailableSummary(now)), findsOneWidget);
    expect(service.requests, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps refresh token, resume and the existing five-minute refresh cadence',
    (tester) async {
      final service = _WeatherService(weather: _weather());
      final now = _campusHour(12);
      await _showHero(tester, service: service, now: () => now);
      await tester.pump(const Duration(minutes: 4));
      expect(service.requests, [false]);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(service.requests, [false, true]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.requests, [false, true, true]);
      await tester.pumpWidget(
        _app(service: service, now: () => now, refreshToken: 1),
      );
      await tester.pump();
      expect(service.requests, [false, true, true, true]);
    },
  );

  testWidgets(
    'existing refresh updates Saturday to Sunday even without weather',
    (tester) async {
      var now = DateTime.utc(2026, 11, 29, 5, 59); // Saturday 23:59 CDMX.
      final service = _WeatherService();
      await _showHero(tester, service: service, now: () => now);
      expect(find.text(CampusWeather.unavailableSummary(now)), findsOneWidget);
      now = DateTime.utc(2026, 11, 29, 6, 1); // Sunday 00:01 CDMX.
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(find.text(CampusWeather.unavailableSummary(now)), findsOneWidget);
      expect(service.requests, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );
}
