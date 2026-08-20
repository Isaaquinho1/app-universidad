class CampusWeather {
  const CampusWeather({
    required this.temperatureCelsius,
    required this.dailyHighCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.fetchedAt,
  });

  final double temperatureCelsius;
  final double dailyHighCelsius;
  final int weatherCode;
  final bool isDay;
  final DateTime fetchedAt;

  bool get isRainy {
    return switch (weatherCode) {
      51 ||
      53 ||
      55 ||
      56 ||
      57 ||
      61 ||
      63 ||
      65 ||
      66 ||
      67 ||
      80 ||
      81 ||
      82 ||
      95 ||
      96 ||
      99 => true,
      _ => false,
    };
  }

  bool get isFoggy => weatherCode == 45 || weatherCode == 48;

  bool get isOvercast => weatherCode == 3;

  bool get shouldUseCloudyImage {
    if (!isDay) {
      return false;
    }

    return switch (weatherCode) {
      0 || 1 => false,
      _ => true,
    };
  }

  String get conditionLabel {
    return switch (weatherCode) {
      0 => 'Despejado',
      1 => 'Mayormente despejado',
      2 => 'Parcialmente nublado',
      3 => 'Nublado',
      45 || 48 => 'Niebla',
      51 || 53 || 55 => 'Llovizna',
      56 || 57 => 'Llovizna helada',
      61 => 'Lluvia ligera',
      63 => 'Lluvia',
      65 => 'Lluvia intensa',
      66 || 67 => 'Lluvia helada',
      71 || 73 || 75 || 77 => 'Nieve',
      80 => 'Chubascos ligeros',
      81 => 'Chubascos',
      82 => 'Chubascos intensos',
      85 || 86 => 'Chubascos de nieve',
      95 => 'Tormenta',
      96 || 99 => 'Tormenta con granizo',
      _ => 'Condiciones variables',
    };
  }

  String get temperatureLabel {
    return '${temperatureCelsius.round()} °C';
  }

  String get dailyHighLabel {
    return '${dailyHighCelsius.round()} °C';
  }

  String contextualSummary(DateTime now) {
    final condition = conditionLabel.toLowerCase();

    final highPhrase = switch (now.hour) {
      < 15 => 'Hoy alcanzaremos una máxima de $dailyHighLabel.',
      < 20 => 'La máxima de hoy será de $dailyHighLabel.',
      _ => 'La máxima de hoy fue de $dailyHighLabel.',
    };

    return 'Ahora mismo hay $temperatureLabel y $condition. $highPhrase';
  }
}
