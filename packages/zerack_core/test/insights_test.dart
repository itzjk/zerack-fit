import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

Food _f(int id, String name, String cat, double kcal, double protein) => Food(
      id: id,
      name: name,
      category: cat,
      per100g: Nutrients(kcal: kcal, proteinG: protein, fatG: 1, carbsG: 1),
    );

void main() {
  group('muscleRecovery (ACSM 2011, 48 h)', () {
    final mon = DateTime(2026, 10, 19, 20);

    MuscleRecovery of(List<MuscleRecovery> r, MuscleGroup g) =>
        r.firstWhere((x) => x.group == g);

    test('sin registros todo está fresco', () {
      final r = muscleRecovery([], mon);
      expect(r.every((x) => x.status == RecoveryStatus.fresh), isTrue);
      expect(r, hasLength(MuscleGroup.values.length));
    });

    test('mismo día y día siguiente: recuperando; 2 días después: listo', () {
      final sets = [TrainedSet(exerciseId: 'bench_press', day: mon)];
      expect(of(muscleRecovery(sets, mon), MuscleGroup.chest).status,
          RecoveryStatus.recovering);
      expect(
          of(muscleRecovery(sets, mon.add(const Duration(days: 1))),
                  MuscleGroup.chest)
              .status,
          RecoveryStatus.recovering);
      final wed = of(muscleRecovery(sets, mon.add(const Duration(days: 2))),
          MuscleGroup.chest);
      expect(wed.status, RecoveryStatus.ready);
      expect(wed.readyOn, DateTime(2026, 10, 21));
    });

    test('cuenta series de los últimos 7 días y usa la sesión más reciente',
        () {
      final sets = [
        for (var i = 0; i < 3; i++)
          TrainedSet(
              exerciseId: 'back_squat',
              day: mon.subtract(const Duration(days: 3))),
        TrainedSet(
            exerciseId: 'leg_press',
            day: mon.subtract(const Duration(days: 9))),
        TrainedSet(exerciseId: 'romanian_deadlift', day: mon),
      ];
      final legs = of(muscleRecovery(sets, mon), MuscleGroup.legs);
      expect(legs.setsLast7Days, 4);
      expect(legs.lastTrained, DateTime(2026, 10, 19));
      expect(legs.status, RecoveryStatus.recovering);
    });

    test('ignora ejercicios desconocidos y fechas futuras', () {
      final r = muscleRecovery([
        TrainedSet(exerciseId: 'nope', day: mon),
        TrainedSet(
            exerciseId: 'bench_press', day: mon.add(const Duration(days: 3))),
      ], mon);
      expect(of(r, MuscleGroup.chest).status, RecoveryStatus.fresh);
    });

    test('conflictsWith avisa los grupos sin 48 h, sin contar abdomen', () {
      final plan = buildWeeklyPlan(level: TrainingLevel.novice, daysPerWeek: 3);
      final a = plan.byId('A');
      final r = muscleRecovery([
        TrainedSet(exerciseId: 'back_squat', day: mon),
        TrainedSet(exerciseId: 'plank', day: mon),
      ], mon.add(const Duration(days: 1)));
      expect(conflictsWith(a, r), {MuscleGroup.legs});
    });
  });

  group('completeDay', () {
    final foods = FoodIndex([
      _f(1, 'Pechuga de pollo', 'proteina', 165, 31),
      _f(2, 'Yogur griego', 'lacteo', 59, 10.2),
      _f(3, 'Lentejas cocidas', 'leguminosa', 116, 9),
      _f(4, 'Galletas', 'dulce', 480, 6),
      _f(5, 'Pechuga de pavo', 'proteina', 104, 17),
    ]);

    test('cubre la proteína que falta sin pasarse de la energía', () {
      final r = completeDay(
        foods: foods,
        targetKcal: 2200,
        eatenKcal: 1500,
        minProteinG: 120,
        eatenProteinG: 70,
      );
      expect(r.remainingProteinG, 50);
      expect(r.suggestions, isNotEmpty);
      expect(r.total.kcal, lessThanOrEqualTo(700));
      expect(r.total.proteinG, greaterThanOrEqualTo(45));
      for (final s in r.suggestions) {
        expect(s.grams % 10, 0);
        expect(s.grams, inInclusiveRange(50, 250));
        expect(s.food.category, isNot('dulce'));
      }
    });

    test('el más denso en proteína va primero', () {
      final r = completeDay(
        foods: foods,
        targetKcal: 2200,
        eatenKcal: 1500,
        minProteinG: 120,
        eatenProteinG: 70,
      );
      // Pollo 31/165 = 0.188 g/kcal > yogur 10.2/59 = 0.173 > pavo 0.163.
      expect(r.suggestions.first.food.name, 'Pechuga de pollo');
    });

    test('no repite variantes del mismo alimento', () {
      final r = completeDay(
        foods: foods,
        targetKcal: 3000,
        eatenKcal: 500,
        minProteinG: 300,
        eatenProteinG: 0,
      );
      final firsts = r.suggestions.map((s) => s.food.name.split(' ').first);
      expect(firsts.toSet().length, r.suggestions.length);
      expect(r.suggestions.length, lessThanOrEqualTo(3));
    });

    test('nada que sugerir si ya cubrió la proteína o no le queda energía', () {
      expect(
        completeDay(
          foods: foods,
          targetKcal: 2000,
          eatenKcal: 1000,
          minProteinG: 100,
          eatenProteinG: 110,
        ).suggestions,
        isEmpty,
      );
      final over = completeDay(
        foods: foods,
        targetKcal: 2000,
        eatenKcal: 2100,
        minProteinG: 100,
        eatenProteinG: 50,
      );
      expect(over.suggestions, isEmpty);
      expect(over.remainingKcal, -100);
    });

    test('si la energía restante no alcanza ni la porción mínima, no sugiere',
        () {
      final r = completeDay(
        foods: foods,
        targetKcal: 2000,
        eatenKcal: 1980,
        minProteinG: 100,
        eatenProteinG: 40,
      );
      expect(r.suggestions, isEmpty);
    });
  });
}
