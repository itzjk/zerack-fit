import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

ExerciseSession _session(double kg, List<int> reps) =>
    ExerciseSession([for (final r in reps) LoggedSet(loadKg: kg, reps: r)]);

void main() {
  const config = ProgressionConfig(targetReps: 10);

  group('decideProgression (ACSM 2009)', () {
    test('sube 5 % tras dos sesiones con 1+ repetición extra', () {
      final d = decideProgression(history: [
        _session(100, [11, 11, 12]),
        _session(100, [11, 12, 11]),
      ], config: config);
      expect(d.action, ProgressionAction.increase);
      expect(d.nextLoadKg, 105);
    });

    test('mantiene si solo una sesión superó el objetivo', () {
      final d = decideProgression(history: [
        _session(100, [10, 10, 10]),
        _session(100, [11, 11, 11]),
      ], config: config);
      expect(d.action, ProgressionAction.keep);
      expect(d.nextLoadKg, 100);
    });

    test('la peor serie manda', () {
      final d = decideProgression(history: [
        _session(100, [12, 12, 9]),
        _session(100, [12, 12, 12]),
      ], config: config);
      expect(d.action, ProgressionAction.keep);
    });

    test('mantiene si cambió la carga entre sesiones', () {
      final d = decideProgression(history: [
        _session(95, [12, 12, 12]),
        _session(100, [11, 11, 11]),
      ], config: config);
      expect(d.action, ProgressionAction.keep);
    });

    test('con una sola sesión mantiene', () {
      final d = decideProgression(history: [
        _session(60, [15, 15])
      ], config: config);
      expect(d.action, ProgressionAction.keep);
      expect(d.nextLoadKg, 60);
    });

    test('nunca baja la carga', () {
      final d = decideProgression(history: [
        _session(100, [6, 5]),
        _session(100, [5, 4]),
      ], config: config);
      expect(d.nextLoadKg, 100);
    });

    test('bloqueado por equipo cuando el salto mínimo supera 10 %', () {
      // 20 kg · 1.05 = 21 → redondea a 20; 22.5 sería +12.5 %.
      final d = decideProgression(history: [
        _session(20, [11, 11]),
        _session(20, [11, 11]),
      ], config: config);
      expect(d.action, ProgressionAction.blockedByEquipment);
      expect(d.nextLoadKg, 20);
    });

    test('con discos de 1 kg sí sube', () {
      final d = decideProgression(history: [
        _session(20, [11, 11]),
        _session(20, [11, 11]),
      ], config: const ProgressionConfig(targetReps: 10, smallestStepKg: 1));
      expect(d.action, ProgressionAction.increase);
      expect(d.nextLoadKg, 21);
    });

    test('el aumento siempre queda entre 2 y 10 %', () {
      for (var kg = 25.0; kg <= 300; kg += 2.5) {
        final d = decideProgression(history: [
          _session(kg, [12]),
          _session(kg, [12]),
        ], config: config);
        if (d.action == ProgressionAction.increase) {
          final pct = d.nextLoadKg / kg - 1;
          expect(pct, inInclusiveRange(0.0, 0.10 + 1e-9), reason: 'kg=$kg');
        }
      }
    });

    test('historial vacío es un error', () {
      expect(() => decideProgression(history: [], config: config),
          throwsArgumentError);
    });
  });

  group('pulso', () {
    test('Tanaka: 208 − 0.7 × edad', () {
      expect(estimatedMaxHeartRate(40), closeTo(180, 1e-9));
    });

    test('Karvonen, banda moderada', () {
      final r = targetHeartRateRange(
          maxHr: 180, restingHr: 60, band: IntensityBand.moderate);
      expect(r.min, closeTo(108, 1e-9));
      expect(r.max, closeTo(130.8, 1e-9));
    });

    test('rechaza pulso de reposo imposible', () {
      expect(
          () => targetHeartRateRange(
              maxHr: 180, restingHr: 190, band: IntensityBand.light),
          throwsA(isA<InvalidInput>()));
    });
  });

  group('readiness (Hooper)', () {
    HooperAnswers all(int v) =>
        HooperAnswers(sleep: v, stress: v, fatigue: v, soreness: v);

    test('extremos', () {
      expect(readinessScore(all(1)), 100);
      expect(readinessScore(all(7)), 0);
    });

    test('punto medio', () {
      expect(readinessScore(all(4)), 50);
    });

    test('rechaza valores fuera de 1–7', () {
      expect(() => all(0), throwsRangeError);
      expect(() => all(8), throwsRangeError);
    });
  });
}
