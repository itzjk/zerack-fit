import '../source.dart';

enum WeightGoal { maintain, lose }

/// Déficit diario para bajar de peso. ACSM 2001 recomienda 500–1000 kcal/día;
/// usamos el extremo bajo, que es el más conservador.
const weightLossDeficitKcal = 500.0;
const weightLossSource = Sources.acsmWeightLoss2001;

class EnergyTarget {
  const EnergyTarget({required this.kcal, required this.limitedByResting});

  final double kcal;

  /// `true` si el déficit completo dejaba la meta por debajo del gasto en
  /// reposo y se recortó. Es una decisión conservadora del proyecto, no una
  /// regla de la guía: la app nunca propone comer menos que el gasto en
  /// reposo estimado.
  final bool limitedByResting;
}

EnergyTarget dailyEnergyTarget({
  required double totalKcal,
  required double restingKcal,
  required WeightGoal goal,
}) {
  switch (goal) {
    case WeightGoal.maintain:
      return EnergyTarget(kcal: totalKcal, limitedByResting: false);
    case WeightGoal.lose:
      final raw = totalKcal - weightLossDeficitKcal;
      return raw < restingKcal
          ? EnergyTarget(kcal: restingKcal, limitedByResting: true)
          : EnergyTarget(kcal: raw, limitedByResting: false);
  }
}

/// Rango de proteína diaria para personas que hacen ejercicio: 1.4–2.0 g/kg
/// (ISSN 2017).
({double minG, double maxG}) dailyProteinRange(double weightKg) {
  if (weightKg.isNaN || weightKg <= 0) {
    throw ArgumentError.value(weightKg, 'weightKg');
  }
  return (minG: 1.4 * weightKg, maxG: 2.0 * weightKg);
}

const proteinSource = Sources.issnProtein2017;
