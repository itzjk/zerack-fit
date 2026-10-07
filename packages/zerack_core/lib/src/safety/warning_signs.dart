import '../source.dart';

/// Signos y síntomas sugestivos de enfermedad cardiovascular, metabólica o
/// renal según ACSM (Riebe et al., 2015, tabla 1).
///
/// La UI traduce cada valor; el motor solo compara identificadores.
enum WarningSign {
  /// Dolor o molestia en pecho, cuello, mandíbula o brazos.
  chestNeckJawArmPain,

  /// Falta de aire en reposo o con esfuerzo leve.
  breathlessnessAtRestOrMildExertion,

  /// Mareo o desmayo (síncope).
  dizzinessOrSyncope,

  /// Falta de aire al acostarse o que despierta por la noche.
  orthopneaOrNocturnalDyspnea,

  /// Hinchazón de tobillos.
  ankleEdema,

  /// Palpitaciones o latidos muy rápidos.
  palpitationsOrTachycardia,

  /// Dolor en piernas al caminar que cede con el reposo (claudicación).
  intermittentClaudication,

  /// Soplo cardiaco conocido.
  knownHeartMurmur,

  /// Fatiga o falta de aire inusual con actividades habituales.
  unusualFatigueOrBreathlessness;

  static const source = Sources.acsmScreening2015;
}

/// Decisión de seguridad ante los signos reportados durante una sesión.
enum SessionSafetyDecision { continueSession, stopAndSeekCare }

/// Cualquier signo de alarma detiene la sesión. Sin excepciones ni umbrales.
SessionSafetyDecision evaluateSessionSafety(Set<WarningSign> reported) =>
    reported.isEmpty
        ? SessionSafetyDecision.continueSession
        : SessionSafetyDecision.stopAndSeekCare;
