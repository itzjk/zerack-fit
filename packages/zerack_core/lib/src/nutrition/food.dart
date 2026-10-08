import '../source.dart';

/// Nutrientes por cada 100 g, tal como los publica el USDA.
class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.fiberG,
  });

  static const zero = Nutrients(kcal: 0, proteinG: 0, fatG: 0, carbsG: 0);

  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double? fiberG;

  Nutrients scaled(double factor) => Nutrients(
        kcal: kcal * factor,
        proteinG: proteinG * factor,
        fatG: fatG * factor,
        carbsG: carbsG * factor,
        fiberG: fiberG == null ? null : fiberG! * factor,
      );

  Nutrients operator +(Nutrients o) => Nutrients(
        kcal: kcal + o.kcal,
        proteinG: proteinG + o.proteinG,
        fatG: fatG + o.fatG,
        carbsG: carbsG + o.carbsG,
        fiberG: fiberG == null && o.fiberG == null
            ? null
            : (fiberG ?? 0) + (o.fiberG ?? 0),
      );

  Map<String, Object?> toJson() => {
        'kcal': kcal,
        'protein': proteinG,
        'fat': fatG,
        'carbs': carbsG,
        if (fiberG != null) 'fiber': fiberG,
      };

  factory Nutrients.fromJson(Map<String, Object?> j) => Nutrients(
        kcal: (j['kcal'] as num).toDouble(),
        proteinG: (j['protein'] as num).toDouble(),
        fatG: (j['fat'] as num).toDouble(),
        carbsG: (j['carbs'] as num).toDouble(),
        fiberG: (j['fiber'] as num?)?.toDouble(),
      );
}

/// Porción común con su peso en gramos (p. ej. "1 taza", 158 g).
class Portion {
  const Portion(this.label, this.grams);
  final String label;
  final double grams;
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.per100g,
    this.aliases = const [],
    this.sourceDescription,
    this.portions = const [],
  });

  /// `fdc_id` del USDA.
  final int id;
  final String name;
  final String category;
  final List<String> aliases;

  /// Descripción original del USDA, para transparencia.
  final String? sourceDescription;
  final Nutrients per100g;
  final List<Portion> portions;

  static const source = Sources.usdaSrLegacy;

  Nutrients forGrams(double grams) {
    if (grams.isNaN || grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'debe ser ≥ 0');
    }
    return per100g.scaled(grams / 100);
  }

  factory Food.fromJson(Map<String, Object?> j) => Food(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        category: j['category'] as String,
        aliases: [for (final a in j['aliases'] as List<Object?>) a as String],
        sourceDescription: j['usda'] as String?,
        per100g: Nutrients.fromJson(j['per100g'] as Map<String, Object?>),
        portions: [
          for (final p in j['portions'] as List<Object?>)
            Portion(
              (p as List<Object?>)[0] as String,
              (p[1] as num).toDouble(),
            ),
        ],
      );
}

/// Quita acentos y pasa a minúsculas para buscar "platano" = "Plátano".
String foldSpanish(String s) {
  const from = 'áéíóúüñàèìòù';
  const to = 'aeiouunaeiou';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Búsqueda en memoria. Todas las palabras de la consulta deben aparecer como
/// inicio de alguna palabra del nombre o de los alias.
class FoodIndex {
  FoodIndex(List<Food> foods)
      : _foods = List.unmodifiable(foods),
        _words = [
          for (final f in foods)
            {
              for (final w in _tokens('${f.name} ${f.aliases.join(' ')}')) w,
            },
        ];

  final List<Food> _foods;
  final List<Set<String>> _words;

  List<Food> get all => _foods;

  static Iterable<String> _tokens(String s) =>
      foldSpanish(s).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);

  Food? byId(int id) {
    for (final f in _foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Food> search(String query, {int limit = 30}) {
    final terms = _tokens(query).toList();
    if (terms.isEmpty) return const [];
    final hits = <(int, Food)>[];
    for (var i = 0; i < _foods.length; i++) {
      final words = _words[i];
      final all = terms.every((t) => words.any((w) => w.startsWith(t)));
      if (!all) continue;
      // Prioriza coincidencias al inicio del nombre.
      final first = _tokens(_foods[i].name).first;
      final rank = first.startsWith(terms.first) ? 0 : 1;
      hits.add((rank, _foods[i]));
    }
    hits.sort((a, b) {
      final r = a.$1.compareTo(b.$1);
      return r != 0 ? r : a.$2.name.length.compareTo(b.$2.name.length);
    });
    return [for (final h in hits.take(limit)) h.$2];
  }
}
