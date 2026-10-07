import '../energy/energy.dart' show InvalidInput;
import '../source.dart';

/// Frecuencia cardiaca máxima estimada: 208 − 0.7 × edad (Tanaka 2001).
double estimatedMaxHeartRate(int ageYears) {
  if (ageYears < 18 || ageYears > 100) {
    throw InvalidInput('ageYears', ageYears);
  }
  return 208 - 0.7 * ageYears;
}

const maxHeartRateSource = Sources.tanaka2001;

/// Bandas de intensidad por % de frecuencia cardiaca de reserva (ACSM).
enum IntensityBand {
  light(0.30, 0.39),
  moderate(0.40, 0.59),
  vigorous(0.60, 0.89);

  const IntensityBand(this.minFraction, this.maxFraction);
  final double minFraction;
  final double maxFraction;

  static const source = Sources.acsmGuidelines;
}

/// Rango de pulso objetivo (lpm) por método de Karvonen.
({double min, double max}) targetHeartRateRange({
  required double maxHr,
  required double restingHr,
  required IntensityBand band,
}) {
  if (restingHr <= 0 || restingHr >= maxHr) {
    throw InvalidInput('restingHr', restingHr);
  }
  final reserve = maxHr - restingHr;
  return (
    min: restingHr + reserve * band.minFraction,
    max: restingHr + reserve * band.maxFraction,
  );
}
