class CampusWeather {
  const CampusWeather({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.fetchedAt,
  });

  final double temperatureCelsius;
  final int weatherCode;
  final bool isDay;
  final DateTime fetchedAt;

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
}
