class CampusWeather {
  const CampusWeather({
    required this.temperatureCelsius,
    required this.dailyHighCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.precipitationMillimeters,
    required this.cloudCoverPercent,
    required this.fetchedAt,
  });

  final double temperatureCelsius;
  final double dailyHighCelsius;
  final int weatherCode;
  final bool isDay;
  final double precipitationMillimeters;
  final double cloudCoverPercent;
  final DateTime fetchedAt;

  bool get hasHeavyRainCode {
    return switch (weatherCode) {
      65 || 67 || 82 || 95 || 96 || 99 => true,
      _ => false,
    };
  }

  bool get isHeavyRain => hasHeavyRainCode && precipitationMillimeters >= 2.5;

  bool get isCloudy => cloudCoverPercent >= 80;

  bool get isFoggy => weatherCode == 45 || weatherCode == 48;

  String get conditionLabel {
    // Open-Meteo puede reportar códigos de llovizna aunque la
    // precipitación actual sea prácticamente imperceptible.
    // En ese caso priorizamos la condición visual dominante.
    if (precipitationMillimeters < 0.3 && cloudCoverPercent >= 80) {
      return 'Nublado';
    }

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
    final hour = now.hour;
    final temperature = temperatureCelsius.round();

    final isVeryCold = temperatureCelsius <= 7;
    final isCold = temperatureCelsius <= 10;
    final isVeryHot = temperatureCelsius >= 31;
    final isHot = temperatureCelsius >= 28;

    // Antes de la apertura: ayudar a preparar la llegada.
    if (hour < 7) {
      if (isHeavyRain) {
        return 'El campus abre a las 7:00. '
            'Si vienes temprano, prepárate para lluvia intensa.';
      }

      if (precipitationMillimeters >= 0.3) {
        return 'El campus abre a las 7:00. '
            'Si vienes temprano, conviene traer paraguas.';
      }

      if (isFoggy) {
        return 'El campus abre a las 7:00. '
            'Hay niebla en los alrededores; llega con precaución.';
      }

      if (isVeryCold) {
        return 'El campus abre a las 7:00. '
            'Se esperan $temperature °C; llega bien abrigado.';
      }

      if (isCold) {
        return 'El campus abre a las 7:00. '
            'La mañana viene fría, con $temperature °C; abrígate bien.';
      }

      if (isVeryHot) {
        return 'El campus abre a las 7:00. '
            'La mañana arrancará muy calurosa, con $temperature °C.';
      }

      if (isHot) {
        return 'El campus abre a las 7:00. '
            'Se esperan $temperature °C; mantente hidratado.';
      }

      if (temperatureCelsius < 16 && cloudCoverPercent >= 80) {
        return 'El campus abre a las 7:00. '
            'Mañana fresca y nublada; lleva algo ligero.';
      }

      if (temperatureCelsius < 16) {
        return 'El campus abre a las 7:00. '
            'La mañana viene fresca; abrígate un poco.';
      }

      if (cloudCoverPercent >= 80) {
        return 'El campus abre a las 7:00. '
            'La mañana viene nublada y tranquila.';
      }

      if (cloudCoverPercent < 30) {
        return 'El campus abre a las 7:00. '
            'Se espera una mañana despejada y agradable.';
      }

      return 'El campus abre a las 7:00. '
          'Las condiciones lucen agradables para comenzar el día.';
    }

    // Jornada activa: 07:00–17:59.
    if (hour < 18) {
      final moment = hour < 12 ? 'Mañana' : 'Tarde';

      if (isHeavyRain) {
        return '$moment de lluvia intensa en el campus; '
            'paraguas e impermeable serán buena idea.';
      }

      if (precipitationMillimeters >= 0.3) {
        return '$moment con algo de lluvia; '
            'conviene llevar paraguas.';
      }

      if (isFoggy) {
        return '$moment fresca y con niebla; '
            'toma precauciones al llegar.';
      }

      if (isVeryCold) {
        return '$moment muy fría en el campus, con $temperature °C; '
            'llega bien abrigado.';
      }

      if (isCold) {
        return '$moment fría en el campus, con $temperature °C; '
            'lleva algo abrigador.';
      }

      if (isVeryHot) {
        return '$moment muy calurosa en el campus, con $temperature °C; '
            'hidrátate y procura buscar sombra.';
      }

      if (isHot) {
        return '$moment calurosa en el campus, con $temperature °C; '
            'mantente hidratado.';
      }

      if (temperatureCelsius < 16 && cloudCoverPercent >= 80) {
        return '$moment fresca y muy nublada; '
            'una capa ligera puede venirte bien.';
      }

      if (temperatureCelsius < 16) {
        return '$moment fresca en el campus; '
            'una capa ligera puede venirte bien.';
      }

      if (cloudCoverPercent >= 80) {
        return '$moment nublada y agradable en el campus.';
      }

      if (cloudCoverPercent < 30) {
        return '$moment despejada y agradable; '
            'pinta como un buen momento para estar aquí.';
      }

      return '$moment agradable en el campus, '
          'con condiciones cómodas para la jornada.';
    }

    // Cierre reciente: 18:00–19:59.
    if (hour < 20) {
      if (isHeavyRain) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina con lluvia intensa en los alrededores.';
      }

      if (precipitationMillimeters >= 0.3) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina con algo de lluvia en los alrededores.';
      }

      if (isFoggy) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina fresca y con niebla en los alrededores.';
      }

      if (isVeryCold) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina muy fría, con $temperature °C.';
      }

      if (isCold) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina fría, con $temperature °C.';
      }

      if (isVeryHot) {
        return 'El campus ya cerró por hoy. '
            'La tarde sigue muy calurosa, con $temperature °C.';
      }

      if (isHot) {
        return 'El campus ya cerró por hoy. '
            'La tarde sigue calurosa, con $temperature °C.';
      }

      if (temperatureCelsius < 16 && cloudCoverPercent >= 80) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina fresca y muy nublada en los alrededores.';
      }

      if (temperatureCelsius < 16) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina fresca en los alrededores.';
      }

      if (cloudCoverPercent >= 80) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina nublada en los alrededores.';
      }

      if (cloudCoverPercent < 30) {
        return 'El campus ya cerró por hoy. '
            'La tarde termina despejada y tranquila.';
      }

      return 'El campus ya cerró por hoy. '
          'La tarde termina tranquila en los alrededores.';
    }

    // Noche: desde las 20:00.
    if (isHeavyRain) {
      return 'El campus ya cerró por hoy. '
          'Continúa la lluvia intensa en los alrededores.';
    }

    if (precipitationMillimeters >= 0.3) {
      return 'El campus ya cerró por hoy. '
          'Continúa algo de lluvia en los alrededores.';
    }

    if (isFoggy) {
      return 'El campus ya cerró por hoy. '
          'Noche fresca y con niebla en los alrededores.';
    }

    if (isVeryCold) {
      return 'El campus ya cerró por hoy. '
          'Noche muy fría en los alrededores, con $temperature °C.';
    }

    if (isCold) {
      return 'El campus ya cerró por hoy. '
          'Noche fría en los alrededores, con $temperature °C.';
    }

    if (isVeryHot) {
      return 'El campus ya cerró por hoy. '
          'La noche sigue muy calurosa, con $temperature °C.';
    }

    if (isHot) {
      return 'El campus ya cerró por hoy. '
          'La noche sigue cálida, con $temperature °C.';
    }

    if (temperatureCelsius < 16 && cloudCoverPercent >= 80) {
      return 'El campus ya cerró por hoy. '
          'Noche fresca y muy nublada en los alrededores.';
    }

    if (temperatureCelsius < 16) {
      return 'El campus ya cerró por hoy. '
          'Noche fresca en los alrededores.';
    }

    if (cloudCoverPercent >= 80) {
      return 'El campus ya cerró por hoy. '
          'Noche nublada y tranquila en los alrededores.';
    }

    if (cloudCoverPercent < 30) {
      return 'El campus ya cerró por hoy. '
          'Noche despejada y tranquila en los alrededores.';
    }

    return 'El campus ya cerró por hoy. '
        'La noche se mantiene tranquila en los alrededores.';
  }
}
