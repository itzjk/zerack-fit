import '../source.dart';

/// Sexo biológico usado por la ecuación de Mifflin-St Jeor.
enum BiologicalSex { male, female }

/// Nivel de actividad física (PAL) según FAO/WHO/UNU 2004, tabla 5.1.
///
/// Rangos del informe: sedentario/ligero 1.40–1.69, activo/moderado
/// 1.70–1.99, vigoroso 2.00–2.40. Usamos los valores de ejemplo del propio
/// informe para cada estilo de vida.
enum ActivityLevel {
  sedentary(1.53),
  active(1.76),
  vigorous(2.25);

  const ActivityLevel(this.pal);
  final double pal;

  static const source = Sources.fao2004;
}

/// Entrada inválida para un cálculo del motor.
class InvalidInput implements Exception {
  const InvalidInput(this.field, this.value);
  final String field;
  final num value;

  @override
  String toString() => 'InvalidInput($field: $value)';
}

void _requireRange(String field, num value, num min, num max) {
  if (value.isNaN || value < min || value > max) {
    throw InvalidInput(field, value);
  }
}

/// Gasto energético en reposo (kcal/día) por Mifflin-St Jeor (1990).
///
/// La ecuación se validó en adultos de 19 a 78 años, por eso rechazamos
/// edades fuera de 18–100 y medidas físicamente improbables.
double restingEnergyKcal({
  required BiologicalSex sex,
  required double weightKg,
  required double heightCm,
  required int ageYears,
}) {
  _requireRange('weightKg', weightKg, 25, 350);
  _requireRange('heightCm', heightCm, 100, 250);
  _requireRange('ageYears', ageYears, 18, 100);

  final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  return switch (sex) {
    BiologicalSex.male => base + 5,
    BiologicalSex.female => base - 161,
  };
}

/// Margen de error de Mifflin-St Jeor: predice el gasto en reposo dentro del
/// ±10 % del medido en la mayoría de adultos (Frankenfield et al., 2005). Lo
/// usamos para mostrar rangos en vez de un número exacto.
const restingEnergyErrorFraction = 0.10;
const restingEnergyErrorSource = Sources.frankenfield2005;

/// Rango estimado alrededor de un valor de energía.
({double low, double high}) energyRange(double kcal) => (
      low: kcal * (1 - restingEnergyErrorFraction),
      high: kcal * (1 + restingEnergyErrorFraction),
    );

/// Gasto energético total diario estimado = reposo × PAL.
double totalEnergyKcal({
  required double restingKcal,
  required ActivityLevel level,
}) =>
    restingKcal * level.pal;

/// Energía de una actividad (kcal) a partir de su MET.
///
/// kcal = MET × kg × horas (Compendium 2024). Con [net] en `true` se resta
/// 1 MET (el reposo), útil para sumar ejercicio sobre un total que ya incluye
/// el gasto basal sin contarlo dos veces.
double activityKcal({
  required double met,
  required double weightKg,
  required Duration duration,
  bool net = false,
}) {
  _requireRange('met', met, 1, 25);
  _requireRange('weightKg', weightKg, 25, 350);
  final hours = duration.inSeconds / 3600;
  final effectiveMet = net ? met - 1 : met;
  return effectiveMet * weightKg * hours;
}

/// Actividad del Compendium 2024 con su código y MET oficiales.
class CompendiumActivity {
  const CompendiumActivity(this.code, this.met, this.description);

  /// Código del Compendium (p. ej. `02054`).
  final String code;
  final double met;

  /// Descripción original en inglés, tal como aparece en la fuente.
  final String description;

  static const source = Sources.compendium2024;
}

/// Subconjunto verificado del Compendium 2024 (categoría Conditioning
/// Exercise). Cada valor se comprobó contra pacompendium.com.
abstract final class Compendium {
  static const resistanceVigorous = CompendiumActivity(
      '02050',
      6.0,
      'Resistance (weight lifting - free weight, nautilus or universal-type), '
          'power lifting or body building, vigorous effort');
  static const resistanceSquatDeadlift = CompendiumActivity('02052', 5.0,
      'Resistance (weight) training, squats, deadlift, slow or explosive effort');
  static const resistanceMultiple = CompendiumActivity(
      '02054',
      3.5,
      'Resistance (weight) training, multiple exercises, 8-15 reps at varied '
          'resistance');
  static const resistanceCircuit = CompendiumActivity(
      '02055',
      5.8,
      'Resistance Training, circuit, reciprocal supersets, peripheral heart '
          'action training');
  static const bodyweightGeneral = CompendiumActivity(
      '02056',
      3.0,
      'Body weight resistance exercises (e.g., squat, lunge, push-up, crunch), '
          'general');
  static const bodyweightHigh = CompendiumActivity(
      '02057',
      6.5,
      'Body weight resistance exercises (e.g., squat, lunge, push-up, crunch), '
          'high intensity');
  static const rowingModerate = CompendiumActivity('02071', 5.0,
      'Rowing, stationary ergometer, general, <100 watts, moderate effort');
  static const ellipticalModerate =
      CompendiumActivity('02048', 5.0, 'Elliptical trainer, moderate effort');
  static const ellipticalVigorous =
      CompendiumActivity('02049', 9.0, 'Elliptical trainer, vigorous effort');
  static const stretchingMild =
      CompendiumActivity('02101', 2.3, 'Stretching, mild');

  static const all = [
    resistanceVigorous,
    resistanceSquatDeadlift,
    resistanceMultiple,
    resistanceCircuit,
    bodyweightGeneral,
    bodyweightHigh,
    rowingModerate,
    ellipticalModerate,
    ellipticalVigorous,
    stretchingMild,
  ];
}
