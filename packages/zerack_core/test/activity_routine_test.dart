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

  group('buildWeeklyPlan (ACSM)', () {
    Set<MuscleGroup> groupsOf(WorkoutTemplate w) =>
        {for (final e in w.exercises) e.exercise.group};

    test('rango de días por nivel (ACSM 2009)', () {
      expect(TrainingLevel.novice.allowsDays(3), isTrue);
      expect(TrainingLevel.novice.allowsDays(4), isFalse);
      expect(TrainingLevel.intermediate.allowsDays(4), isTrue);
      expect(TrainingLevel.advanced.allowsDays(6), isTrue);
      expect(TrainingLevel.advanced.allowsDays(7), isFalse);
      expect(TrainingLevel.advanced.clampDays(2), 4);
      expect(
        () => buildWeeklyPlan(level: TrainingLevel.novice, daysPerWeek: 5),
        throwsArgumentError,
      );
    });

    test('cada combinación válida entrena exactamente N días', () {
      for (final level in TrainingLevel.values) {
        for (var d = level.minDays; d <= level.maxDays; d++) {
          for (final gym in [true, false]) {
            final plan =
                buildWeeklyPlan(level: level, daysPerWeek: d, gymAccess: gym);
            final training = plan.week.where((w) => w.workout != null);
            expect(training, hasLength(d), reason: '$level $d gym=$gym');
            expect(plan.week, hasLength(7));
            expect(plan.forWeekday(7), isNull, reason: 'domingo descansa');
          }
        }
      }
    });

    test('ningún grupo muscular se repite en días consecutivos (≥48 h)', () {
      for (final level in TrainingLevel.values) {
        for (var d = level.minDays; d <= level.maxDays; d++) {
          for (final gym in [true, false]) {
            final plan =
                buildWeeklyPlan(level: level, daysPerWeek: d, gymAccess: gym);
            for (var day = 1; day < 7; day++) {
              final today = plan.forWeekday(day);
              final tomorrow = plan.forWeekday(day + 1);
              if (today == null || tomorrow == null) continue;
              final shared = groupsOf(today).intersection(groupsOf(tomorrow))
                ..remove(MuscleGroup.core);
              expect(shared, isEmpty,
                  reason: '$level $d gym=$gym días $day y ${day + 1}');
            }
          }
        }
      }
    });

    test('la semana cubre piernas, pecho, espalda y hombros', () {
      for (final level in TrainingLevel.values) {
        for (var d = level.minDays; d <= level.maxDays; d++) {
          for (final gym in [true, false]) {
            final plan =
                buildWeeklyPlan(level: level, daysPerWeek: d, gymAccess: gym);
            final groups = {
              for (final w in plan.workouts) ...groupsOf(w),
            };
            expect(
              groups,
              containsAll([
                MuscleGroup.legs,
                MuscleGroup.chest,
                MuscleGroup.back,
                MuscleGroup.shoulders,
              ]),
              reason: '$level $d gym=$gym',
            );
          }
        }
      }
    });

    test('principiante 2 series, el resto 3; 8–12 reps', () {
      final n = buildWeeklyPlan(level: TrainingLevel.novice, daysPerWeek: 3);
      final a = buildWeeklyPlan(level: TrainingLevel.advanced, daysPerWeek: 6);
      for (final e in n.workouts.expand((w) => w.exercises)) {
        expect(e.sets, 2);
      }
      for (final e in a.workouts.expand((w) => w.exercises)) {
        expect(e.sets, 3);
        if (e.exercise.id != 'plank') {
          expect((e.minReps, e.maxReps), (8, 12));
        }
      }
    });

    test('descanso: 2 min multiarticular, 60 s monoarticular', () {
      final plan =
          buildWeeklyPlan(level: TrainingLevel.intermediate, daysPerWeek: 4);
      for (final e in plan.workouts.expand((w) => w.exercises)) {
        expect(
          e.rest,
          e.exercise.multiJoint
              ? const Duration(minutes: 2)
              : const Duration(seconds: 60),
        );
      }
    });

    test('muy activo: lunes a sábado con empuje/jalón/piernas', () {
      final plan =
          buildWeeklyPlan(level: TrainingLevel.advanced, daysPerWeek: 6);
      expect([for (var d = 1; d <= 6; d++) plan.forWeekday(d)!.id],
          ['push', 'pull', 'legs', 'push', 'pull', 'legs']);
    });

    test('nextFrom salta los descansos y da la vuelta a la semana', () {
      final plan = buildWeeklyPlan(level: TrainingLevel.novice, daysPerWeek: 2);
      expect(plan.nextFrom(1).weekday, 1);
      expect(plan.nextFrom(2).weekday, 4);
      expect(plan.nextFrom(5).weekday, 1);
      expect(() => plan.forWeekday(0), throwsArgumentError);
    });

    test('todos los ids existen y el catálogo no repite ids', () {
      final ids = exerciseCatalog.map((e) => e.id).toSet();
      expect(ids.length, exerciseCatalog.length);
      expect(() => exerciseById('nope'), throwsArgumentError);
    });
  });
}
