import 'dart:math' as math;

/// Muestra de la cámara: brillo promedio del canal rojo en un instante.
class PpgSample {
  const PpgSample(this.time, this.red);
  final Duration time;
  final double red;
}

enum PulseFailure {
  /// Menos de [PulseEstimator.minDuration] de señal.
  tooShort,

  /// La imagen no parece un dedo cubriendo la cámara con el flash.
  noFinger,

  /// Muy pocos latidos detectados o intervalos demasiado irregulares
  /// (movimiento, presión del dedo).
  poorSignal,
}

class PulseResult {
  const PulseResult.ok(this.bpm, this.quality) : failure = null;
  const PulseResult.failed(this.failure)
      : bpm = null,
        quality = 0;

  final double? bpm;

  /// 0.0–1.0: fracción de intervalos consistentes con la mediana.
  final double quality;
  final PulseFailure? failure;

  bool get isOk => failure == null;
}

/// Estima el pulso en reposo por fotopletismografía con la cámara.
///
/// Es una **estimación de bienestar, no una medición médica**. Rechaza la
/// lectura cuando la señal no es confiable en lugar de dar un número dudoso.
class PulseEstimator {
  const PulseEstimator();

  static const minDuration = Duration(seconds: 20);

  /// Rango fisiológico aceptado en reposo (lpm).
  static const minBpm = 40.0;
  static const maxBpm = 180.0;

  /// Con el flash encendido y el dedo encima, el rojo domina y es brillante.
  static const minRedLevel = 100.0;

  /// Mínimo de intervalos (latido a latido) para dar resultado.
  static const minIntervals = 10;

  /// Fracción mínima de intervalos dentro de ±20 % de la mediana.
  static const minQuality = 0.7;

  PulseResult estimate(List<PpgSample> samples) {
    if (samples.length < 3 ||
        samples.last.time - samples.first.time < minDuration) {
      return const PulseResult.failed(PulseFailure.tooShort);
    }
    final meanRed =
        samples.map((s) => s.red).reduce((a, b) => a + b) / samples.length;
    if (meanRed < minRedLevel) {
      return const PulseResult.failed(PulseFailure.noFinger);
    }

    final t = [for (final s in samples) s.time.inMicroseconds / 1e6];
    final fs = (samples.length - 1) / (t.last - t.first);

    // Pasa-banda simple: quita la tendencia lenta (~1.5 s) y suaviza el ruido
    // rápido (~0.1 s). La sangre que entra con cada latido oscurece el rojo,
    // así que invertimos la señal para que cada latido sea un pico.
    final raw = [for (final s in samples) -s.red];
    final baseline = _movingAverage(raw, math.max(3, (fs * 1.5).round()));
    final detrended = [
      for (var i = 0; i < raw.length; i++) raw[i] - baseline[i]
    ];
    final smooth = _movingAverage(detrended, math.max(1, (fs * 0.1).round()));

    // Picos locales por encima de un umbral relativo, con periodo refractario
    // del pulso máximo aceptado.
    final refractory = 60 / maxBpm;
    final sd = _std(smooth);
    if (sd == 0) return const PulseResult.failed(PulseFailure.poorSignal);
    final peaks = <double>[];
    for (var i = 1; i < smooth.length - 1; i++) {
      final v = smooth[i];
      if (v > smooth[i - 1] && v >= smooth[i + 1] && v > 0.3 * sd) {
        if (peaks.isEmpty || t[i] - peaks.last >= refractory) {
          peaks.add(t[i]);
        }
      }
    }

    final intervals = [
      for (var i = 1; i < peaks.length; i++) peaks[i] - peaks[i - 1],
    ].where((d) => d >= 60 / maxBpm && d <= 60 / minBpm).toList();
    if (intervals.length < minIntervals) {
      return const PulseResult.failed(PulseFailure.poorSignal);
    }

    final median = _median(intervals);
    final consistent =
        intervals.where((d) => (d - median).abs() <= 0.2 * median).length;
    final quality = consistent / intervals.length;
    if (quality < minQuality) {
      return const PulseResult.failed(PulseFailure.poorSignal);
    }
    final bpm = 60 / median;
    if (bpm < minBpm || bpm > maxBpm) {
      return const PulseResult.failed(PulseFailure.poorSignal);
    }

    // Segunda opinión: la señal debe repetirse con ese periodo. El ruido
    // puede producir picos espaciados por casualidad, pero no una
    // autocorrelación alta justo en el periodo encontrado.
    final r = _autocorrelationNear(smooth, (median * fs).round());
    if (r < minAutocorrelation) {
      return const PulseResult.failed(PulseFailure.poorSignal);
    }
    return PulseResult.ok(bpm, math.min(quality, r));
  }

  /// Autocorrelación normalizada mínima en el periodo del pulso.
  static const minAutocorrelation = 0.5;

  /// Máxima autocorrelación normalizada en [lag] ± 1 muestra.
  static double _autocorrelationNear(List<double> x, int lag) {
    final n = x.length;
    final m = x.reduce((a, b) => a + b) / n;
    final c = [for (final v in x) v - m];
    var energy = 0.0;
    for (final v in c) {
      energy += v * v;
    }
    var best = -1.0;
    for (var l = math.max(1, lag - 1); l <= math.min(n - 2, lag + 1); l++) {
      var sum = 0.0;
      for (var i = 0; i + l < n; i++) {
        sum += c[i] * c[i + l];
      }
      best = math.max(best, sum / energy * n / (n - l));
    }
    return best;
  }

  static List<double> _movingAverage(List<double> x, int window) {
    final half = window ~/ 2;
    final prefix = List<double>.filled(x.length + 1, 0);
    for (var i = 0; i < x.length; i++) {
      prefix[i + 1] = prefix[i] + x[i];
    }
    return [
      for (var i = 0; i < x.length; i++)
        () {
          final a = math.max(0, i - half);
          final b = math.min(x.length, i + half + 1);
          return (prefix[b] - prefix[a]) / (b - a);
        }(),
    ];
  }

  static double _std(List<double> x) {
    final m = x.reduce((a, b) => a + b) / x.length;
    final v =
        x.map((e) => (e - m) * (e - m)).reduce((a, b) => a + b) / x.length;
    return math.sqrt(v);
  }

  static double _median(List<double> x) {
    final s = [...x]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}
