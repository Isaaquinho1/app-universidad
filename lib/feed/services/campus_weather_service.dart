import 'package:dio/dio.dart';
import 'package:conecta_itt/feed/models/campus_weather.dart';

class CampusWeatherService {
  CampusWeatherService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static CampusWeather? _cachedWeather;

  static const _cacheDuration = Duration(minutes: 15);

  static const double _campusLatitude = 19.200556;
  static const double _campusLongitude = -99.141667;

  Future<CampusWeather?> getCurrentWeather({bool forceRefresh = false}) async {
    final cached = _cachedWeather;

    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: const {
          'latitude': _campusLatitude,
          'longitude': _campusLongitude,
          'current': 'temperature_2m,weather_code,is_day',
          'timezone': 'America/Mexico_City',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final current = response.data?['current'];

      if (current is! Map<String, dynamic>) {
        return cached;
      }

      final temperature = current['temperature_2m'];
      final weatherCode = current['weather_code'];
      final isDay = current['is_day'];

      if (temperature is! num || weatherCode is! num || isDay is! num) {
        return cached;
      }

      final weather = CampusWeather(
        temperatureCelsius: temperature.toDouble(),
        weatherCode: weatherCode.toInt(),
        isDay: isDay.toInt() == 1,
        fetchedAt: DateTime.now(),
      );

      _cachedWeather = weather;

      return weather;
    } on DioException {
      return cached;
    } catch (_) {
      return cached;
    }
  }
}
