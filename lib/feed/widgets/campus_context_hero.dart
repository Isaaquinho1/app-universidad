import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const CampusContextHero({this.refreshToken = 0, super.key});

  final int refreshToken;

  @override
  State<CampusContextHero> createState() => _CampusContextHeroState();
}

class _CampusContextHeroState extends State<CampusContextHero>
    with WidgetsBindingObserver {
  final CampusWeatherService _weatherService = CampusWeatherService();

  CampusWeather? _weather;
  Timer? _weatherRefreshTimer;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
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

    try {
      final weather = await _weatherService.getCurrentWeather(
        forceRefresh: forceRefresh,
      );

      if (!mounted || weather == null) {
        return;
      }

      setState(() {
        _weather = weather;
      });
    } finally {
      _isLoadingWeather = false;
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
    final now = DateTime.now();
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
      (baseAlignment.y - 0.48).clamp(-1.0, 1.0),
    );

    // BLOQUE_13_7C
    // BLOQUE_13_10A_APLICADO
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: useLightText ? Brightness.dark : Brightness.light,
        statusBarIconBrightness:
            useLightText ? Brightness.light : Brightness.dark,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: SizedBox(
          height: 238,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _assetForContext(now, _weather),
                fit: BoxFit.cover,
                alignment: heroAlignment,
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 262),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONECTA ITT',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w700,
                              color:
                                  useLightText
                                      ? Colors.white
                                      : Color(0xFF27334E),
                              shadows:
                                  useLightText
                                      ? const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Publicaciones',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1.05,
                              letterSpacing: -1.1,
                              fontWeight: FontWeight.w800,
                              color:
                                  useLightText
                                      ? Colors.white
                                      : Color(0xFF111827),
                              shadows:
                                  useLightText
                                      ? const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Mantente al día con las últimas noticias, '
                            'comunicados y eventos de tu universidad.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.32,
                              fontWeight: FontWeight.w400,
                              color:
                                  useLightText
                                      ? Colors.white
                                      : Color(0xFF384253),
                              shadows:
                                  useLightText
                                      ? const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                      : null,
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
