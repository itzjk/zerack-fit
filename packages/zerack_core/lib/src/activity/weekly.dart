import '../source.dart';

enum ActivityIntensity { moderate, vigorous }

class ActivityBout {
  const ActivityBout({
    required this.day,
    required this.minutes,
    required this.intensity,
    this.strength = false,
  });

  final DateTime day;
  final int minutes;
  final ActivityIntensity intensity;

  /// Ejercicio de fortalecimiento muscular (pesas, peso corporal).
  final bool strength;
}

/// Resumen de 7 días contra las recomendaciones de la OMS 2020 para adultos:
/// 150–300 min moderados (o 75–150 vigorosos, o su equivalente) y fuerza 2 o
/// más días por semana.
class WeeklySummary {
  const WeeklySummary({
    required this.moderateEquivalentMinutes,
    required this.strengthDays,
  });

  /// Minutos moderados + 2 × minutos vigorosos (equivalencia de la OMS).
  final int moderateEquivalentMinutes;
  final int strengthDays;

  static const aerobicMinimum = 150;
  static const aerobicUpper = 300;
  static const strengthDaysMinimum = 2;
  static const source = Sources.who2020;

  bool get meetsAerobic => moderateEquivalentMinutes >= aerobicMinimum;
  bool get meetsStrength => strengthDays >= strengthDaysMinimum;

  /// 0.0–1.0 hacia el mínimo aeróbico.
  double get aerobicProgress =>
      (moderateEquivalentMinutes / aerobicMinimum).clamp(0, 1).toDouble();
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Suma las actividades de los 7 días que terminan en [today] (incluido).
WeeklySummary summarizeWeek(Iterable<ActivityBout> bouts, DateTime today) {
  final end = _dateOnly(today);
  final start = end.subtract(const Duration(days: 6));
  var minutes = 0;
  final strengthDays = <DateTime>{};
  for (final b in bouts) {
    final d = _dateOnly(b.day);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    if (b.minutes < 0) throw ArgumentError.value(b.minutes, 'minutes');
    minutes +=
        b.intensity == ActivityIntensity.vigorous ? b.minutes * 2 : b.minutes;
    if (b.strength) strengthDays.add(d);
  }
  return WeeklySummary(
    moderateEquivalentMinutes: minutes,
    strengthDays: strengthDays.length,
  );
}
