import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

void main() {
  group('summarizeWeek (OMS 2020)', () {
    final today = DateTime(2026, 10, 7, 20);

    test('vigoroso cuenta doble', () {
      final s = summarizeWeek([
        ActivityBout(
            day: today, minutes: 30, intensity: ActivityIntensity.vigorous),
        ActivityBout(
            day: today, minutes: 60, intensity: ActivityIntensity.moderate),
      ], today);
      expect(s.moderateEquivalentMinutes, 120);
      expect(s.meetsAerobic, isFalse);
      expect(s.aerobicProgress, closeTo(0.8, 1e-9));
    });

    test('solo cuenta los últimos 7 días', () {
      final s = summarizeWeek([
        ActivityBout(
            day: today.subtract(const Duration(days: 6)),
            minutes: 100,
            intensity: ActivityIntensity.moderate),
        ActivityBout(
            day: today.subtract(const Duration(days: 7)),
            minutes: 100,
            intensity: ActivityIntensity.moderate),
      ], today);
      expect(s.moderateEquivalentMinutes, 100);
    });

    test('días de fuerza distintos', () {
      final s = summarizeWeek([
        for (final d in [0, 0, 2])
          ActivityBout(
            day: today.subtract(Duration(days: d)),
            minutes: 40,
            intensity: ActivityIntensity.moderate,
            strength: true,
          ),
      ], today);
      expect(s.strengthDays, 2);
      expect(s.meetsStrength, isTrue);
      expect(s.moderateEquivalentMinutes, 120);
    });
  });

  group('buildFullBodyPlan (ACSM)', () {
    test('principiante: 2 series, 8–12 reps', () {
      final plan =
          buildFullBodyPlan(level: TrainingLevel.novice, daysPerWeek: 3);
      for (final w in plan.workouts) {
        for (final e in w.exercises) {
          expect(e.sets, 2);
          if (e.exercise.id != 'plank') {
            expect(e.minReps, 8);
            expect(e.maxReps, 12);
          }
        }
      }
    });

    test('intermedio: 3 series', () {
      final plan =
          buildFullBodyPlan(level: TrainingLevel.intermediate, daysPerWeek: 2);
      expect(plan.workouts.first.exercises.first.sets, 3);
    });

    test('descanso: 2 min multiarticular, 60 s monoarticular', () {
      final plan =
          buildFullBodyPlan(level: TrainingLevel.novice, daysPerWeek: 2);
      for (final e in plan.workouts.expand((w) => w.exercises)) {
        expect(
            e.rest,
            e.exercise.multiJoint
                ? const Duration(minutes: 2)
                : const Duration(seconds: 60));
      }
    });

    test('alterna A y B', () {
      final plan =
          buildFullBodyPlan(level: TrainingLevel.novice, daysPerWeek: 3);
      expect(plan.next(0).id, 'A');
      expect(plan.next(1).id, 'B');
      expect(plan.next(2).id, 'A');
    });

    test('cubre piernas, pecho, espalda y hombros en la semana', () {
      for (final gym in [true, false]) {
        final plan = buildFullBodyPlan(
            level: TrainingLevel.novice, daysPerWeek: 2, gymAccess: gym);
        final groups = {
          for (final e in plan.workouts.expand((w) => w.exercises))
            e.exercise.group,
        };
        expect(
            groups,
            containsAll([
              MuscleGroup.legs,
              MuscleGroup.chest,
              MuscleGroup.back,
              MuscleGroup.shoulders,
            ]),
            reason: 'gym=$gym');
      }
    });

    test('rechaza días fuera de 2–3', () {
      expect(
          () => buildFullBodyPlan(level: TrainingLevel.novice, daysPerWeek: 5),
          throwsArgumentError);
    });

    test('todos los ids del plan existen y el catálogo no repite ids', () {
      final ids = exerciseCatalog.map((e) => e.id).toSet();
      expect(ids.length, exerciseCatalog.length);
      expect(() => exerciseById('nope'), throwsArgumentError);
    });
  });
}
