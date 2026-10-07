import '../safety/warning_signs.dart';
import '../source.dart';

/// Respuestas del screening previo a la participación (ACSM 2015).
class ScreeningAnswers {
  const ScreeningAnswers({
    required this.exercisesRegularly,
    required this.hasKnownCardiometabolicRenalDisease,
    required this.signs,
  });

  /// Ejercicio planeado y estructurado de al menos 30 min a intensidad
  /// moderada, 3 o más días por semana, durante los últimos 3 meses.
  final bool exercisesRegularly;

  /// Enfermedad cardiovascular, metabólica (diabetes tipo 1 o 2) o renal
  /// diagnosticada.
  final bool hasKnownCardiometabolicRenalDisease;

  final Set<WarningSign> signs;
}

/// Resultado del algoritmo. La UI decide el texto; aquí solo hay códigos.
enum ScreeningOutcome {
  /// Sin autorización médica necesaria. Si no hace ejercicio: empezar ligero
  /// a moderado y progresar gradualmente.
  clearedStartLightToModerate,

  /// Sin autorización médica necesaria; puede seguir o progresar.
  clearedContinue,

  /// Recomendada autorización médica antes de empezar.
  medicalClearanceBeforeStarting,

  /// Puede seguir con intensidad moderada; necesita autorización médica
  /// antes de pasar a vigorosa.
  medicalClearanceBeforeVigorous,

  /// Debe suspender el ejercicio y buscar autorización médica.
  stopAndSeekMedicalClearance,
}

extension ScreeningOutcomeGate on ScreeningOutcome {
  /// ¿Puede la app generar rutinas sin que el usuario confirme antes una
  /// autorización médica?
  bool get allowsTrainingWithoutClearance => switch (this) {
        ScreeningOutcome.clearedStartLightToModerate ||
        ScreeningOutcome.clearedContinue ||
        ScreeningOutcome.medicalClearanceBeforeVigorous =>
          true,
        ScreeningOutcome.medicalClearanceBeforeStarting ||
        ScreeningOutcome.stopAndSeekMedicalClearance =>
          false,
      };

  /// ¿Se permite intensidad vigorosa sin autorización médica?
  bool get allowsVigorous => this == ScreeningOutcome.clearedContinue;
}

/// Algoritmo de screening de ACSM (Riebe et al., 2015, figura 2).
ScreeningOutcome evaluateScreening(ScreeningAnswers a) {
  final symptomatic = a.signs.isNotEmpty;

  if (!a.exercisesRegularly) {
    if (symptomatic || a.hasKnownCardiometabolicRenalDisease) {
      return ScreeningOutcome.medicalClearanceBeforeStarting;
    }
    return ScreeningOutcome.clearedStartLightToModerate;
  }

  if (symptomatic) return ScreeningOutcome.stopAndSeekMedicalClearance;
  return a.hasKnownCardiometabolicRenalDisease
      ? ScreeningOutcome.medicalClearanceBeforeVigorous
      : ScreeningOutcome.clearedContinue;
}

const screeningSource = Sources.acsmScreening2015;
