import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/app/app.dart';
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
    final appState = context.watch<AppBloc>().state;

    final institutionalName =
        appState.institutionalProfile?.displayName?.trim() ?? '';
    final userName = appState.user.name?.trim() ?? '';

    final displayName =
        institutionalName.isNotEmpty ? institutionalName : userName;

    final firstName = _firstName(displayName);

    return SizedBox(
      height: 390,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _assetForContext(now, _weather),
            fit: BoxFit.cover,
            alignment: _imageAlignmentForContext(now, _weather),
          ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.28),
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                24,
                AppSpacing.lg,
                14,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formattedDate(now),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black45),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _greeting(now, firstName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -0.6,
                        shadows: [
                          Shadow(blurRadius: 12, color: Colors.black54),
                        ],
                      ),
                    ),
                    if (_weather != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _weather!.contextualSummary(now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black45),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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

  String _firstName(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return '';
    }

    return normalized.split(RegExp(r'\s+')).first;
  }

  String _greeting(DateTime dateTime, String firstName) {
    final hour = dateTime.hour;

    final greeting = switch (hour) {
      >= 5 && < 12 => 'Buenos días',
      >= 12 && < 19 => 'Buenas tardes',
      _ => 'Buenas noches',
    };

    if (firstName.isEmpty) {
      return '$greeting!';
    }

    return '$greeting, $firstName!';
  }

  String _formattedDate(DateTime dateTime) {
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];

    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];

    return '${_capitalize(weekday)}, ${dateTime.day} de $month';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
