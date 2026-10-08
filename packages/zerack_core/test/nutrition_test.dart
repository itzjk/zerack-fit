import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

const _rice = Food(
  id: 168878,
  name: 'Arroz blanco cocido',
  category: 'cereal',
  per100g: Nutrients(kcal: 130, proteinG: 2.69, fatG: 0.28, carbsG: 28.17),
  portions: [Portion('1 taza', 158)],
);
const _banana = Food(
  id: 173944,
  name: 'Plátano',
  category: 'fruta',
  aliases: ['banana', 'guineo'],
  per100g: Nutrients(kcal: 89, proteinG: 1.09, fatG: 0.33, carbsG: 22.84),
);
const _plantain = Food(
  id: 168216,
  name: 'Plátano macho verde hervido',
  category: 'tuberculo',
  per100g: Nutrients(kcal: 116, proteinG: 0.8, fatG: 0.2, carbsG: 31),
);

void main() {
  group('Food', () {
    test('escala por gramos', () {
      final n = _rice.forGrams(158);
      expect(n.kcal, closeTo(205.4, 1e-9));
      expect(n.carbsG, closeTo(44.5086, 1e-9));
    });

    test('rechaza gramos negativos', () {
      expect(() => _rice.forGrams(-1), throwsArgumentError);
    });

    test('suma nutrientes', () {
      final n = _rice.forGrams(100) + _banana.forGrams(100);
      expect(n.kcal, 219);
      expect(n.fiberG, isNull);
    });

    test('fromJson con el formato del generador', () {
      final f = Food.fromJson({
        'id': 1,
        'name': 'X',
        'category': 'c',
        'aliases': ['y'],
        'usda': 'Desc',
        'per100g': {'kcal': 10, 'protein': 1, 'fat': 2, 'carbs': 3, 'fiber': 4},
        'portions': [
          ['1 taza', 100],
        ],
      });
      expect(f.per100g.fiberG, 4);
      expect(f.portions.single.grams, 100);
      expect(f.sourceDescription, 'Desc');
    });
  });

  group('FoodIndex', () {
    final index = FoodIndex([_rice, _plantain, _banana]);

    test('ignora acentos y mayúsculas', () {
      expect(index.search('PLATANO').first.id, _banana.id);
    });

    test('busca por alias', () {
      expect(index.search('guineo').single.id, _banana.id);
    });

    test('todas las palabras deben coincidir', () {
      expect(index.search('platano macho').single.id, _plantain.id);
      expect(index.search('arroz macho'), isEmpty);
    });

    test('prefijos', () {
      expect(index.search('arr').single.id, _rice.id);
    });

    test('consulta vacía no regresa nada', () {
      expect(index.search('  '), isEmpty);
    });

    test('byId', () {
      expect(index.byId(168878)?.name, 'Arroz blanco cocido');
      expect(index.byId(1), isNull);
    });
  });

  test('foldSpanish', () {
    expect(
        foldSpanish('Jalapeño Plátano Pingüino'), 'jalapeno platano pinguino');
  });

  group('metas', () {
    test('mantener = gasto total', () {
      final t = dailyEnergyTarget(
          totalKcal: 2500, restingKcal: 1600, goal: WeightGoal.maintain);
      expect(t.kcal, 2500);
      expect(t.limitedByResting, isFalse);
    });

    test('bajar resta 500 kcal (ACSM 2001)', () {
      final t = dailyEnergyTarget(
          totalKcal: 2500, restingKcal: 1600, goal: WeightGoal.lose);
      expect(t.kcal, 2000);
    });

    test('nunca por debajo del gasto en reposo', () {
      final t = dailyEnergyTarget(
          totalKcal: 1700, restingKcal: 1400, goal: WeightGoal.lose);
      expect(t.kcal, 1400);
      expect(t.limitedByResting, isTrue);
    });

    test('proteína 1.4–2.0 g/kg (ISSN 2017)', () {
      final r = dailyProteinRange(70);
      expect(r.minG, closeTo(98, 1e-9));
      expect(r.maxG, closeTo(140, 1e-9));
      expect(() => dailyProteinRange(0), throwsArgumentError);
    });
  });
}
