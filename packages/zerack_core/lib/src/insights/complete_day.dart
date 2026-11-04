import 'dart:math' as math;

import '../nutrition/food.dart';
import '../source.dart';

/// Una sugerencia de alimento con su porción.
class FoodSuggestion {
  const FoodSuggestion(this.food, this.grams);
  final Food food;
  final double grams;

  Nutrients get nutrients => food.forGrams(grams);
}

class DayCompletion {
  const DayCompletion({
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.suggestions,
  });

  /// Lo que falta para la meta de energía (puede ser ≤ 0).
  final double remainingKcal;

  /// Lo que falta para el mínimo de proteína (puede ser ≤ 0).
  final double remainingProteinG;
  final List<FoodSuggestion> suggestions;

  Nutrients get total =>
      suggestions.fold(Nutrients.zero, (s, f) => s + f.nutrients);

  bool get proteinCovered => remainingProteinG <= 0;

  static const sources = [Sources.issnProtein2017, Sources.usdaSrLegacy];
}

/// Propone hasta [maxItems] alimentos de la base del USDA para llegar al
/// mínimo de proteína del día (ISSN 2017) **sin pasarse de la meta de
/// energía**. Todos los números salen de la base; no hay estimaciones.
///
/// Elige por densidad de proteína (g por kcal), en porciones redondeadas a
/// 10 g y de [minGrams] a [maxGrams] por alimento, una sola vez cada uno.
DayCompletion completeDay({
  required FoodIndex foods,
  required double targetKcal,
  required double eatenKcal,
  required double minProteinG,
  required double eatenProteinG,
  Set<String> categories = const {'proteina', 'lacteo', 'leguminosa'},
  int maxItems = 3,
  double minGrams = 50,
  double maxGrams = 250,
}) {
  final remainingKcal = targetKcal - eatenKcal;
  final remainingProtein = minProteinG - eatenProteinG;
  final out = <FoodSuggestion>[];
  if (remainingProtein <= 0 || remainingKcal <= 0) {
    return DayCompletion(
      remainingKcal: remainingKcal,
      remainingProteinG: remainingProtein,
      suggestions: out,
    );
  }

  final candidates = [
    for (final f in foods.all)
      if (categories.contains(f.category) &&
          f.per100g.kcal > 0 &&
          f.per100g.proteinG >= 8)
        f,
  ]..sort((a, b) {
      final da = a.per100g.proteinG / a.per100g.kcal;
      final db = b.per100g.proteinG / b.per100g.kcal;
      final c = db.compareTo(da);
      return c != 0 ? c : a.name.length.compareTo(b.name.length);
    });

  var kcalLeft = remainingKcal;
  var proteinLeft = remainingProtein;
  final usedNames = <String>{};
  for (final f in candidates) {
    if (out.length >= maxItems || proteinLeft <= 0) break;
    // Evita dos variantes del mismo alimento (p. ej. dos tipos de atún).
    final key = f.name.split(' ').first.toLowerCase();
    if (!usedNames.add(key)) continue;
    final perGramKcal = f.per100g.kcal / 100;
    final perGramProtein = f.per100g.proteinG / 100;
    final forProtein = proteinLeft / perGramProtein;
    final byKcal = kcalLeft / perGramKcal;
    var grams = math.min(math.min(forProtein, byKcal), maxGrams);
    grams = (grams / 10).floor() * 10;
    if (grams < minGrams) continue;
    out.add(FoodSuggestion(f, grams.toDouble()));
    kcalLeft -= grams * perGramKcal;
    proteinLeft -= grams * perGramProtein;
  }
  return DayCompletion(
    remainingKcal: remainingKcal,
    remainingProteinG: remainingProtein,
    suggestions: out,
  );
}
