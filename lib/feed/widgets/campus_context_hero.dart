import 'package:flutter/material.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/feed/models/campus_weather.dart';
import 'package:conecta_itt/feed/services/campus_weather_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeather();
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

  Future<void> _refreshContextAfterResume() async {
    final weather = await _weatherService.getCurrentWeather();

    if (!mounted) {
      return;
    }

    setState(() {
      if (weather != null) {
        _weather = weather;
      }
    });
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    final weather = await _weatherService.getCurrentWeather(
      forceRefresh: forceRefresh,
    );

    if (!mounted || weather == null) {
      return;
    }

    setState(() {
      _weather = weather;
    });
  }

  @override
  void dispose() {
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

  String _assetForContext(DateTime dateTime, CampusWeather? weather) {
    if (weather != null) {
      if (!weather.isDay) {
        return 'assets/campus/campus_noche.png';
      }

      if (weather.shouldUseCloudyImage) {
        return 'assets/campus/campus_nublado.png';
      }
    }

    return _assetForTime(dateTime);
  }

  Alignment _imageAlignmentForContext(
    DateTime dateTime,
    CampusWeather? weather,
  ) {
    if (weather != null) {
      if (!weather.isDay) {
        return const Alignment(0, -0.62);
      }

      if (weather.shouldUseCloudyImage) {
        return const Alignment(0, -0.42);
      }
    }

    return _imageAlignmentForTime(dateTime);
  }

  String _assetForTime(DateTime dateTime) {
    final hour = dateTime.hour;

    if (hour >= 5 && hour < 9) {
      return 'assets/campus/campus_amanecer.png';
    }

    if (hour >= 9 && hour < 14) {
      return 'assets/campus/campus_medio_dia.png';
    }

    if (hour >= 14 && hour < 18) {
      return 'assets/campus/campus_tarde.png';
    }

    if (hour >= 18 && hour < 20) {
      return 'assets/campus/campus_casi_noche.png';
    }

    return 'assets/campus/campus_noche.png';
  }

  Alignment _imageAlignmentForTime(DateTime dateTime) {
    final hour = dateTime.hour;

    if (hour >= 5 && hour < 9) {
      return const Alignment(0, -0.42);
    }

    if (hour >= 9 && hour < 14) {
      return const Alignment(0, -0.40);
    }

    if (hour >= 14 && hour < 18) {
      return const Alignment(0, -0.40);
    }

    if (hour >= 18 && hour < 20) {
      return const Alignment(0, -0.42);
    }

    return const Alignment(0, -0.62);
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
