import 'package:clock/clock.dart';
import 'package:conecta_itt/feed/models/campus_context_time.dart';
import 'package:conecta_itt/feed/models/campus_weather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

CampusWeather weather({
  double temperature = 21,
  int code = 0,
  double precipitation = 0,
  double cloud = 10,
}) => CampusWeather(
  temperatureCelsius: temperature,
  dailyHighCelsius: 25,
  weatherCode: code,
  isDay: true,
  precipitationMillimeters: precipitation,
  cloudCoverPercent: cloud,
  fetchedAt: DateTime.utc(2026, 11, 28),
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('campus time does not replace the notification time zone', () {
    final previousLocal = tz.local;
    addTearDown(() => tz.setLocalLocation(previousLocal));
    final tokyo = tz.getLocation('Asia/Tokyo');
    tz.setLocalLocation(tokyo);
    final local = CampusContextTime.inMexicoCity(DateTime.utc(2026, 11, 29, 6));
    expect(local.weekday, DateTime.sunday);
    expect(local.hour, 0);
    expect(identical(tz.local, tokyo), isTrue);
  });

  test('injectable clock uses the campus date rather than UTC', () {
    withClock(Clock.fixed(DateTime.utc(2026, 11, 29, 5, 59)), () {
      final local = CampusContextTime.now();
      expect(local.weekday, DateTime.saturday);
      expect(local.hour, 23);
      expect(local.minute, 59);
    });
  });

  test('Saturday changes to Sunday at midnight in Mexico City', () {
    expect(
      CampusWeekendPolicy.closureMessage(DateTime.utc(2026, 11, 29, 5, 59)),
      'Este sábado el campus permanece cerrado.',
    );
    expect(
      CampusWeekendPolicy.closureMessage(DateTime.utc(2026, 11, 29, 6)),
      'Este domingo el campus permanece cerrado.',
    );
    expect(
      CampusWeekendPolicy.closureMessage(DateTime.utc(2026, 11, 28, 5, 59)),
      isNull,
    );
    expect(
      CampusWeekendPolicy.closureMessage(DateTime.utc(2026, 11, 30, 6)),
      isNull,
    );
  });

  test('a date in another device zone represents the same campus instant', () {
    final tokyo = tz.getLocation('Asia/Tokyo');
    final saturday = tz.TZDateTime(tokyo, 2026, 11, 29, 14, 59);
    final sunday = tz.TZDateTime(tokyo, 2026, 11, 29, 15);
    expect(weather().contextualSummary(saturday), contains('Este sábado'));
    expect(weather().contextualSummary(sunday), contains('Este domingo'));
  });

  // Fixed snapshots of all existing weekday branches before this change.
  const baseline = [
    (
      label: 'heavy rain',
      temperature: 14.0,
      code: 65,
      precipitation: 3.0,
      cloud: 90.0,
      expected: <String>[
        'El campus abre a las 7:00. Si vienes temprano, prepárate para lluvia intensa.',
        'Mañana de lluvia intensa en el campus; paraguas e impermeable serán buena idea.',
        'Tarde de lluvia intensa en el campus; paraguas e impermeable serán buena idea.',
        'El campus ya cerró por hoy. La tarde termina con lluvia intensa en los alrededores.',
        'El campus ya cerró por hoy. Continúa la lluvia intensa en los alrededores.',
      ],
    ),
    (
      label: 'rain',
      temperature: 14.0,
      code: 61,
      precipitation: 0.5,
      cloud: 90.0,
      expected: <String>[
        'El campus abre a las 7:00. Si vienes temprano, conviene traer paraguas.',
        'Mañana con algo de lluvia; conviene llevar paraguas.',
        'Tarde con algo de lluvia; conviene llevar paraguas.',
        'El campus ya cerró por hoy. La tarde termina con algo de lluvia en los alrededores.',
        'El campus ya cerró por hoy. Continúa algo de lluvia en los alrededores.',
      ],
    ),
    (
      label: 'fog',
      temperature: 14.0,
      code: 45,
      precipitation: 0.0,
      cloud: 50.0,
      expected: <String>[
        'El campus abre a las 7:00. Hay niebla en los alrededores; llega con precaución.',
        'Mañana fresca y con niebla; toma precauciones al llegar.',
        'Tarde fresca y con niebla; toma precauciones al llegar.',
        'El campus ya cerró por hoy. La tarde termina fresca y con niebla en los alrededores.',
        'El campus ya cerró por hoy. Noche fresca y con niebla en los alrededores.',
      ],
    ),
    (
      label: 'very cold',
      temperature: 5.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. Se esperan 5 °C; llega bien abrigado.',
        'Mañana muy fría en el campus, con 5 °C; llega bien abrigado.',
        'Tarde muy fría en el campus, con 5 °C; llega bien abrigado.',
        'El campus ya cerró por hoy. La tarde termina muy fría, con 5 °C.',
        'El campus ya cerró por hoy. Noche muy fría en los alrededores, con 5 °C.',
      ],
    ),
    (
      label: 'cold',
      temperature: 9.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. La mañana viene fría, con 9 °C; abrígate bien.',
        'Mañana fría en el campus, con 9 °C; lleva algo abrigador.',
        'Tarde fría en el campus, con 9 °C; lleva algo abrigador.',
        'El campus ya cerró por hoy. La tarde termina fría, con 9 °C.',
        'El campus ya cerró por hoy. Noche fría en los alrededores, con 9 °C.',
      ],
    ),
    (
      label: 'very hot',
      temperature: 32.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. La mañana arrancará muy calurosa, con 32 °C.',
        'Mañana muy calurosa en el campus, con 32 °C; hidrátate y procura buscar sombra.',
        'Tarde muy calurosa en el campus, con 32 °C; hidrátate y procura buscar sombra.',
        'El campus ya cerró por hoy. La tarde sigue muy calurosa, con 32 °C.',
        'El campus ya cerró por hoy. La noche sigue muy calurosa, con 32 °C.',
      ],
    ),
    (
      label: 'hot',
      temperature: 29.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. Se esperan 29 °C; mantente hidratado.',
        'Mañana calurosa en el campus, con 29 °C; mantente hidratado.',
        'Tarde calurosa en el campus, con 29 °C; mantente hidratado.',
        'El campus ya cerró por hoy. La tarde sigue calurosa, con 29 °C.',
        'El campus ya cerró por hoy. La noche sigue cálida, con 29 °C.',
      ],
    ),
    (
      label: 'cool cloudy',
      temperature: 14.0,
      code: 3,
      precipitation: 0.0,
      cloud: 90.0,
      expected: <String>[
        'El campus abre a las 7:00. Mañana fresca y nublada, lleva algo ligero.',
        'Mañana fresca y muy nublada, algo abrigador puede venirte bien.',
        'Tarde fresca y muy nublada, algo abrigador puede venirte bien.',
        'El campus ya cerró por hoy. La tarde termina fresca y muy nublada en los alrededores.',
        'El campus ya cerró por hoy. Noche fresca y muy nublada en los alrededores.',
      ],
    ),
    (
      label: 'cool',
      temperature: 14.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. La mañana viene fresca, abrígate un poco.',
        'Mañana fresca en el campus, algo abrigador puede venirte bien.',
        'Tarde fresca en el campus, algo abrigador puede venirte bien.',
        'El campus ya cerró por hoy. La tarde termina fresca en los alrededores.',
        'El campus ya cerró por hoy. Noche fresca en los alrededores.',
      ],
    ),
    (
      label: 'cloudy',
      temperature: 21.0,
      code: 3,
      precipitation: 0.0,
      cloud: 90.0,
      expected: <String>[
        'El campus abre a las 7:00. La mañana viene nublada y tranquila.',
        'Mañana nublada y agradable en el campus.',
        'Tarde nublada y agradable en el campus.',
        'El campus ya cerró por hoy. La tarde termina nublada en los alrededores.',
        'El campus ya cerró por hoy. Noche nublada y tranquila en los alrededores.',
      ],
    ),
    (
      label: 'clear',
      temperature: 21.0,
      code: 0,
      precipitation: 0.0,
      cloud: 20.0,
      expected: <String>[
        'El campus abre a las 7:00. Se espera una mañana despejada y agradable.',
        'Mañana despejada y agradable; pinta como un buen momento para estar aquí.',
        'Tarde despejada y agradable; pinta como un buen momento para estar aquí.',
        'El campus ya cerró por hoy. La tarde termina despejada y tranquila.',
        'El campus ya cerró por hoy. Noche despejada y tranquila en los alrededores.',
      ],
    ),
    (
      label: 'variable',
      temperature: 21.0,
      code: 2,
      precipitation: 0.0,
      cloud: 50.0,
      expected: <String>[
        'El campus abre a las 7:00. Las condiciones lucen agradables para comenzar el día.',
        'Mañana agradable en el campus, con condiciones cómodas para la jornada.',
        'Tarde agradable en el campus, con condiciones cómodas para la jornada.',
        'El campus ya cerró por hoy. La tarde termina tranquila en los alrededores.',
        'El campus ya cerró por hoy. La noche se mantiene tranquila en los alrededores.',
      ],
    ),
  ];
  for (var weekday = DateTime.monday; weekday <= DateTime.friday; weekday++) {
    test('weekday $weekday preserves every existing weather message', () {
      const hours = [6, 10, 15, 18, 22];
      for (final scenario in baseline) {
        final conditions = weather(
          temperature: scenario.temperature,
          code: scenario.code,
          precipitation: scenario.precipitation,
          cloud: scenario.cloud,
        );
        for (var i = 0; i < hours.length; i++) {
          // November 23, 2026 is Monday; UTC+6 here encodes campus local time.
          final instant = DateTime.utc(2026, 11, 22 + weekday, hours[i] + 6);
          expect(
            conditions.contextualSummary(instant),
            scenario.expected[i],
            reason: '${scenario.label}, weekday $weekday, hour ${hours[i]}',
          );
        }
      }
    });
  }

  test('sunny Saturday keeps useful lightweight clothing advice', () {
    final summary = weather().contextualSummary(DateTime.utc(2026, 11, 28, 17));
    expect(summary, contains('Este sábado el campus permanece cerrado.'));
    expect(summary, contains('Mañana despejada'));
    expect(summary, contains('ropa ligera'));
    expect(summary, contains('hidratado'));
  });

  test('rainy Saturday distinguishes observed and possible rain', () {
    final instant = DateTime.utc(2026, 11, 28, 21);
    final observed = weather(
      code: 61,
      precipitation: 0.5,
    ).contextualSummary(instant);
    final possible = weather(code: 65).contextualSummary(instant);
    expect(observed, contains('con algo de lluvia'));
    expect(observed, contains('paraguas'));
    expect(possible, contains('posibilidad de lluvia'));
    expect(possible, contains('paraguas'));
    expect(possible, isNot(contains('lluvia intensa')));
    expect(possible, isNot(contains('con algo de lluvia')));
  });

  test('heavy rain requires both code and measured precipitation', () {
    final instant = DateTime.utc(2026, 11, 28, 21);
    final heavy = weather(
      code: 65,
      precipitation: 3,
    ).contextualSummary(instant);
    final ordinary = weather(
      code: 61,
      precipitation: 3,
    ).contextualSummary(instant);
    expect(heavy, contains('lluvia intensa'));
    expect(heavy, contains('impermeable'));
    expect(ordinary, isNot(contains('intensa')));
  });

  test('cold Sunday retains temperature and warm clothing advice', () {
    final summary = weather(
      temperature: 9,
    ).contextualSummary(DateTime.utc(2026, 11, 29, 16));
    expect(summary, contains('Este domingo el campus permanece cerrado.'));
    expect(summary, contains('fría, con 9 °C'));
    expect(summary, contains('abrigador'));
  });

  test('cloudy Sunday keeps clouds and light jacket recommendation', () {
    final summary = weather(
      code: 3,
      cloud: 95,
    ).contextualSummary(DateTime.utc(2026, 11, 29, 21));
    expect(summary, contains('Este domingo'));
    expect(summary, contains('Tarde nublada'));
    expect(summary, contains('chamarra ligera'));
  });

  test(
    'weekend night and predawn never invite arrival or announce opening',
    () {
      for (final instant in [
        DateTime.utc(2026, 11, 29, 4),
        DateTime.utc(2026, 11, 29, 9),
      ]) {
        final summary = weather(
          temperature: 14,
          cloud: 90,
        ).contextualSummary(instant);
        expect(summary, contains('fresca y nublada'));
        expect(summary, contains('abrigador'));
        expect(summary, isNot(contains('abre')));
        expect(summary, isNot(contains('llega')));
        expect(RegExp('cerrado').allMatches(summary), hasLength(1));
        expect(summary.length, lessThan(180));
      }
      expect(
        weather().contextualSummary(DateTime.utc(2026, 11, 29, 4)),
        contains('Noche despejada'),
      );
      expect(
        weather().contextualSummary(DateTime.utc(2026, 11, 29, 9)),
        contains('Madrugada despejada'),
      );
    },
  );

  test('hot weekend night keeps hydration without daytime shadow advice', () {
    final conditions = weather(temperature: 32);
    final night = conditions.contextualSummary(DateTime.utc(2026, 11, 29, 4));
    expect(night, contains('Noche muy calurosa'));
    expect(night, contains('hidratado'));
    expect(night, isNot(contains('sombra')));
    final day = conditions.contextualSummary(DateTime.utc(2026, 11, 28, 18));
    expect(day, contains('busca sombra'));
  });

  test(
    'weekend without weather reports closure without invented conditions',
    () {
      for (final instant in [
        DateTime.utc(2026, 11, 28, 18),
        DateTime.utc(2026, 11, 29, 18),
      ]) {
        final summary = CampusWeather.unavailableSummary(instant);
        expect(summary, contains('el campus permanece cerrado.'));
        expect(summary, contains('El clima no está disponible'));
        expect(summary, isNot(contains('°C')));
        expect(summary, isNot(contains('lluvia')));
        expect(summary, isNot(contains('nublad')));
        expect(RegExp('cerrado').allMatches(summary), hasLength(1));
        final loading = CampusWeather.unavailableSummary(
          instant,
          isLoading: true,
        );
        expect(loading, contains('Consultando el clima de los alrededores...'));
      }
      expect(
        CampusWeather.unavailableSummary(DateTime.utc(2026, 11, 28, 18)),
        startsWith('Este sábado'),
      );
      expect(
        CampusWeather.unavailableSummary(DateTime.utc(2026, 11, 29, 18)),
        startsWith('Este domingo'),
      );
    },
  );

  test('weekday loading text remains unchanged and failure is explicit', () {
    final monday = DateTime.utc(2026, 11, 23, 18);
    expect(
      CampusWeather.unavailableSummary(monday, isLoading: true),
      'Consultando el clima del campus...',
    );
    expect(
      CampusWeather.unavailableSummary(monday),
      'El clima del campus no está disponible por el momento.',
    );
  });
}
