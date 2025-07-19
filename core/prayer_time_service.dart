import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

class PrayerTimeResult {
  final Map<String, DateTime> times;
  final String nextPrayerName;
  final Duration timeUntilNext;

  PrayerTimeResult({
    required this.times,
    required this.nextPrayerName,
    required this.timeUntilNext,
  });
}

class PrayerTimeService {
  static PrayerTimeResult calculate({
    required double latitude,
    required double longitude,
    CalculationParameters? overrideParams,
  }) {
    final coords = Coordinates(latitude, longitude);
    final now = DateTime.now();
    final dateComponents = DateComponents(now.year, now.month, now.day);

    // ✅ Correct way: enum value + extension method
    final baseParams =
        overrideParams ?? CalculationMethod.muslim_world_league.getParameters();

    // Ensure madhab (try/catch in case of different field shape)
    try {
      baseParams.madhab = Madhab.shafi;
    } catch (_) {}

    final pt = PrayerTimes(coords, dateComponents, baseParams);

    final times = <String, DateTime>{
      'Fajr': pt.fajr,
      'Sunrise': pt.sunrise,
      'Dhuhr': pt.dhuhr,
      'Asr': pt.asr,
      'Maghrib': pt.maghrib,
      'Isha': pt.isha,
    };

    final (nextName, until) = _nextPrayerInfo(pt, now);

    return PrayerTimeResult(
      times: times,
      nextPrayerName: nextName,
      timeUntilNext: until,
    );
  }

  /// Returns (nextPrayerName, durationUntilNext)
  static (String, Duration) _nextPrayerInfo(PrayerTimes pt, DateTime now) {
    final ordered = <String, DateTime>{
      'Fajr': pt.fajr,
      'Dhuhr': pt.dhuhr,
      'Asr': pt.asr,
      'Maghrib': pt.maghrib,
      'Isha': pt.isha,
    };

    for (final e in ordered.entries) {
      if (now.isBefore(e.value)) {
        return (e.key, e.value.difference(now));
      }
    }

    // Tomorrow Fajr
    final tomorrow = now.add(const Duration(days: 1));
    final dc = DateComponents(tomorrow.year, tomorrow.month, tomorrow.day);
    final tomorrowPt =
    PrayerTimes(pt.coordinates, dc, pt.calculationParameters);
    return ('Fajr', tomorrowPt.fajr.difference(now));
  }

  static String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  /// Optional stream updating every minute.
  static Stream<PrayerTimeResult> stream({
    required double latitude,
    required double longitude,
  }) async* {
    while (true) {
      yield calculate(latitude: latitude, longitude: longitude);
      final now = DateTime.now();
      final msToNextMinute =
          60000 - (now.second * 1000 + now.millisecond);
      await Future.delayed(Duration(milliseconds: msToNextMinute));
    }
  }
}
