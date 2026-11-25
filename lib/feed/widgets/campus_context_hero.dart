import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conecta_itt/feed/models/campus_context_time.dart';
import 'package:conecta_itt/feed/models/campus_weather.dart';
import 'package:conecta_itt/feed/services/campus_weather_service.dart';

enum _CampusHeroScene {
  heavyRainAfternoon,
  foggyEvening,
  earlyMorning,
  sunrise,
  midday,
  afternoon,
  evening,
  night,
  cloudyMorning,
  cloudyAfternoon,
}

class CampusContextHero extends StatefulWidget {
  const CampusContextHero({
    this.refreshToken = 0,
    this.now,
    this.weatherService,
    super.key,
  });

  final int refreshToken;

  /// Optional dependencies keep time and weather deterministic in widget tests.
  final DateTime Function()? now;
  final CampusWeatherService? weatherService;

  @override
  State<CampusContextHero> createState() => _CampusContextHeroState();
}

class _CampusContextHeroState extends State<CampusContextHero>
    with WidgetsBindingObserver {
  late final CampusWeatherService _weatherService;

  CampusWeather? _weather;
  Timer? _weatherRefreshTimer;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weatherService ?? CampusWeatherService();
    WidgetsBinding.instance.addObserver(this);
    _loadWeather();
    _startWeatherRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant CampusContextHero oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadWeather(forceRefresh: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshContextAfterResume();
    }
  }

  void _startWeatherRefreshTimer() {
    _weatherRefreshTimer?.cancel();

    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) {
        return;
      }

      _loadWeather(forceRefresh: true);
    });
  }

  Future<void> _refreshContextAfterResume() async {
    _startWeatherRefreshTimer();
    await _loadWeather(forceRefresh: true);
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    if (_isLoadingWeather) {
      return;
    }

    _isLoadingWeather = true;

    CampusWeather? weather;
    try {
      weather = await _weatherService.getCurrentWeather(
        forceRefresh: forceRefresh,
      );
    } finally {
      if (mounted) {
        setState(() {
          // The service already falls back to its cache. Keep the last known
          // weather when no data is available, and rebuild date-only messages.
          _weather = weather ?? _weather;
          _isLoadingWeather = false;
        });
      } else {
        _isLoadingWeather = false;
      }
    }
  }

  @override
  void dispose() {
    _weatherRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = CampusContextTime.inMexicoCity(
      widget.now?.call() ?? CampusContextTime.now(),
    );
    final scene = _sceneForContext(now, _weather);
    final useLightText = switch (scene) {
      _CampusHeroScene.earlyMorning ||
      _CampusHeroScene.evening ||
      _CampusHeroScene.night ||
      _CampusHeroScene.foggyEvening ||
      _CampusHeroScene.heavyRainAfternoon => true,
      _ => false,
    };
    final baseAlignment = _imageAlignmentForContext(now, _weather);
    final heroAlignment = Alignment(
      baseAlignment.x,
      (baseAlignment.y - 0.72).clamp(-1.0, 1.0).toDouble(),
    );
    final message =
        _weather?.contextualSummary(now) ??
        CampusWeather.unavailableSummary(now, isLoading: _isLoadingWeather);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: useLightText ? Brightness.dark : Brightness.light,
        statusBarIconBrightness:
            useLightText ? Brightness.light : Brightness.dark,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding =
                (width * 0.06).clamp(16.0, 24.0).toDouble();
            final safePadding = MediaQuery.paddingOf(context);
            final availableWidth =
                width - safePadding.horizontal - horizontalPadding * 2;
            final textScale =
                MediaQuery.textScalerOf(context).scale(12.5) / 12.5;
            // Leave the building visible at normal sizes, and give larger type
            // the full available line width instead of shrinking or truncating.
            final textWidth =
                width < 360 || textScale > 1.3
                    ? availableWidth
                    : availableWidth * 0.82;
            final textEnd =
                (safePadding.left + horizontalPadding + textWidth) / width;
            final foreground =
                useLightText ? Colors.white : const Color(0xFF27334E);
            const bottomFade = 32.0;

            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 238),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _assetForContext(now, _weather),
                      fit: BoxFit.cover,
                      alignment: heroAlignment,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        // Fade only below the text: the content reserves this
                        // padding even when accessibility type grows the hero.
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) {
                          final fadeStart =
                              ((rect.height - bottomFade) / rect.height)
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, fadeStart, 1.0],
                          ).createShader(rect);
                        },
                        child: DecoratedBox(
                          key: const ValueKey('campus-hero-scrim'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: [0.0, textEnd, 1.0],
                              colors: [
                                if (useLightText) ...[
                                  const Color(0xA807182B),
                                  const Color(0xA807182B),
                                  const Color(0x0007182B),
                                ] else ...[
                                  const Color(0xBDFFFFFF),
                                  const Color(0xBDFFFFFF),
                                  const Color(0x00FFFFFF),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        bottomFade,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        heightFactor: 1,
                        child: SizedBox(
                          width: textWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONECTA ITT',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  letterSpacing: 3.0,
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Publicaciones',
                                style: TextStyle(
                                  fontSize: 29,
                                  height: 1.08,
                                  letterSpacing: -1.1,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      useLightText
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                key: const ValueKey('campus-hero-message'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _CampusHeroScene _sceneForContext(DateTime dateTime, CampusWeather? weather) {
    final hour = dateTime.hour;

    // La fotografía de lluvia representa una precipitación fuerte
    // específicamente durante la tarde.
    if ((weather?.isHeavyRain ?? false) && hour >= 14 && hour < 18) {
      return _CampusHeroScene.heavyRainAfternoon;
    }

    // Escena específica de neblina durante la transición a la noche.
    if ((weather?.isFoggy ?? false) && hour >= 17 && hour < 20) {
      return _CampusHeroScene.foggyEvening;
    }

    if (hour < 5) {
      return _CampusHeroScene.earlyMorning;
    }

    if (hour >= 20) {
      return _CampusHeroScene.night;
    }

    // La misma condición nublada utiliza fotografías distintas
    // según la franja horaria.
    if (weather?.isCloudy ?? false) {
      if (hour >= 5 && hour < 14) {
        return _CampusHeroScene.cloudyMorning;
      }

      if (hour >= 14 && hour < 18) {
        return _CampusHeroScene.cloudyAfternoon;
      }
    }

    if (hour >= 5 && hour < 9) {
      return _CampusHeroScene.sunrise;
    }

    if (hour >= 9 && hour < 14) {
      return _CampusHeroScene.midday;
    }

    if (hour >= 14 && hour < 18) {
      return _CampusHeroScene.afternoon;
    }

    return _CampusHeroScene.evening;
  }

  String _assetForContext(DateTime dateTime, CampusWeather? weather) {
    final scene = _sceneForContext(dateTime, weather);

    return switch (scene) {
      _CampusHeroScene.heavyRainAfternoon =>
        'assets/campus/campus_lloviendo.png',
      _CampusHeroScene.foggyEvening =>
        'assets/campus/campus_neblina_casi_noche.png',
      _CampusHeroScene.earlyMorning => 'assets/campus/campus_madrugada.png',
      _CampusHeroScene.sunrise => 'assets/campus/campus_amanecer.png',
      _CampusHeroScene.midday => 'assets/campus/campus_medio_dia.png',
      _CampusHeroScene.afternoon => 'assets/campus/campus_tarde.png',
      _CampusHeroScene.evening => 'assets/campus/campus_casi_noche.png',
      _CampusHeroScene.night => 'assets/campus/campus_noche.png',
      _CampusHeroScene.cloudyMorning => 'assets/campus/campus_nublado.png',
      _CampusHeroScene.cloudyAfternoon =>
        'assets/campus/campus_super_nublado.png',
    };
  }

  Alignment _imageAlignmentForContext(
    DateTime dateTime,
    CampusWeather? weather,
  ) {
    final scene = _sceneForContext(dateTime, weather);

    return switch (scene) {
      _CampusHeroScene.heavyRainAfternoon ||
      _CampusHeroScene.foggyEvening ||
      _CampusHeroScene.earlyMorning ||
      _CampusHeroScene.midday ||
      _CampusHeroScene.afternoon ||
      _CampusHeroScene.cloudyMorning ||
      _CampusHeroScene.cloudyAfternoon => const Alignment(0, -0.40),

      _CampusHeroScene.sunrise ||
      _CampusHeroScene.evening => const Alignment(0, -0.42),

      _CampusHeroScene.night => const Alignment(0, -0.62),
    };
  }
}
