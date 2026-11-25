import 'package:clock/clock.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Campus dates always follow Mexico City, regardless of the device time zone.
abstract final class CampusContextTime {
  static final tz.Location _location = _loadLocation();

  static tz.Location _loadLocation() {
    try {
      return tz.getLocation('America/Mexico_City');
    } on tz.LocationNotFoundException {
      // Notifications may have initialized the shared database already. Only
      // load it if needed, and preserve their selected local time zone.
      final previousLocal = tz.timeZoneDatabase.isInitialized ? tz.local : null;
      tz_data.initializeTimeZones();
      if (previousLocal != null) tz.setLocalLocation(previousLocal);
      return tz.getLocation('America/Mexico_City');
    }
  }

  static DateTime inMexicoCity(DateTime instant) =>
      tz.TZDateTime.from(instant, _location);

  static DateTime now() => inMexicoCity(clock.now());
}

/// Approved communication rule for this version. Future opening exceptions
/// belong here, rather than in individual weather or presentation branches.
abstract final class CampusWeekendPolicy {
  static String? closureMessage(DateTime instant) {
    final weekday = CampusContextTime.inMexicoCity(instant).weekday;
    final day = switch (weekday) {
      DateTime.saturday => 'sábado',
      DateTime.sunday => 'domingo',
      _ => null,
    };
    return day == null ? null : 'Este $day el campus permanece cerrado.';
  }
}
