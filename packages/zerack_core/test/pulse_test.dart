import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

/// Señal sintética: brillo base + latido (pulso estrecho) + ruido.
List<PpgSample> _signal({
  required double bpm,
  double seconds = 30,
  double fps = 30,
  double base = 200,
  double amplitude = 2,
  double noise = 0.3,
  double drift = 5,
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  final period = 60 / bpm;
  return [
    for (var i = 0; i < seconds * fps; i++)
      () {
        final t = i / fps;
        final phase = (t % period) / period;
        // La sangre oscurece el rojo: caída breve en cada latido.
        final beat = math.exp(-math.pow((phase - 0.2) / 0.08, 2).toDouble());
        final red = base -
            amplitude * beat +
            drift * math.sin(2 * math.pi * t / 20) +
            noise * (rnd.nextDouble() - 0.5);
        return PpgSample(Duration(microseconds: (t * 1e6).round()), red);
      }(),
  ];
}

void main() {
  const est = PulseEstimator();

  for (final bpm in [50.0, 65.0, 80.0, 100.0, 130.0]) {
    test('recupera $bpm lpm con error < 3 lpm', () {
      final r = est.estimate(_signal(bpm: bpm));
      expect(r.isOk, isTrue, reason: '${r.failure}');
      expect(r.bpm, closeTo(bpm, 3));
      expect(r.quality, greaterThanOrEqualTo(PulseEstimator.minQuality));
    });
  }

  test('funciona con 24 fps irregulares', () {
    final s = _signal(bpm: 72, fps: 24);
    final jittered = [
      for (final (i, x) in s.indexed)
        PpgSample(x.time + Duration(milliseconds: i.isEven ? 4 : -4), x.red),
    ];
    final r = est.estimate(jittered);
    expect(r.bpm, closeTo(72, 3));
  });

  test('menos de 20 s: muy corto', () {
    expect(est.estimate(_signal(bpm: 70, seconds: 10)).failure,
        PulseFailure.tooShort);
  });

  test('imagen oscura: no hay dedo', () {
    expect(est.estimate(_signal(bpm: 70, base: 30)).failure,
        PulseFailure.noFinger);
  });

  test('puro ruido: señal pobre, no inventa un número', () {
    final rnd = math.Random(7);
    final s = [
      for (var i = 0; i < 900; i++)
        PpgSample(Duration(milliseconds: (i * 33.3).round()),
            200 + 10 * (rnd.nextDouble() - 0.5)),
    ];
    final r = est.estimate(s);
    expect(r.isOk, isFalse);
    expect(r.bpm, isNull);
  });

  test('señal plana: señal pobre', () {
    final s = [
      for (var i = 0; i < 900; i++)
        PpgSample(Duration(milliseconds: (i * 33.3).round()), 200),
    ];
    expect(est.estimate(s).failure, PulseFailure.poorSignal);
  });
}
