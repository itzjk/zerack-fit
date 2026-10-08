import 'package:zerack_core/zerack_core.dart';

/// Textos en español para los identificadores del motor. El motor compara
/// enums; aquí solo vive la redacción.
abstract final class Es {
  static const disclaimer =
      'ZERACK es una herramienta de entrenamiento y bienestar. No diagnostica '
      'ni trata enfermedades y no sustituye a un profesional de la salud.\n\n'
      'Los números que ves (calorías, pulso, nota del día) son estimaciones '
      'basadas en fórmulas publicadas, no mediciones médicas.\n\n'
      'Tus datos se guardan solo en este teléfono. No hay cuenta ni servidor.';

  static String sex(BiologicalSex s) => switch (s) {
    BiologicalSex.male => 'Hombre',
    BiologicalSex.female => 'Mujer',
  };

  static String activity(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => 'Sedentario o ligero',
    ActivityLevel.active => 'Activo',
    ActivityLevel.vigorous => 'Muy activo',
  };

  static String activityHint(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary =>
      'Trabajo sentado, poco movimiento fuera del ejercicio.',
    ActivityLevel.active =>
      'Trabajo de pie o caminas mucho, o haces ejercicio casi a diario.',
    ActivityLevel.vigorous =>
      'Trabajo físico pesado o entrenas fuerte muchas horas a la semana.',
  };

  static String sign(WarningSign s) => switch (s) {
    WarningSign.chestNeckJawArmPain =>
      'Dolor o molestia en pecho, cuello, mandíbula o brazos',
    WarningSign.breathlessnessAtRestOrMildExertion =>
      'Falta de aire en reposo o con poco esfuerzo',
    WarningSign.dizzinessOrSyncope => 'Mareo o desmayo',
    WarningSign.orthopneaOrNocturnalDyspnea =>
      'Falta de aire al acostarte o que te despierta de noche',
    WarningSign.ankleEdema => 'Tobillos hinchados',
    WarningSign.palpitationsOrTachycardia =>
      'Palpitaciones o latidos muy rápidos',
    WarningSign.intermittentClaudication =>
      'Dolor en las piernas al caminar que se quita al descansar',
    WarningSign.knownHeartMurmur => 'Soplo en el corazón diagnosticado',
    WarningSign.unusualFatigueOrBreathlessness =>
      'Cansancio o falta de aire inusual en actividades normales',
  };

  static String outcomeTitle(ScreeningOutcome o) => switch (o) {
    ScreeningOutcome.clearedStartLightToModerate =>
      'Puedes empezar, poco a poco',
    ScreeningOutcome.clearedContinue => 'Puedes seguir entrenando',
    ScreeningOutcome.medicalClearanceBeforeStarting =>
      'Habla con tu médico antes de empezar',
    ScreeningOutcome.medicalClearanceBeforeVigorous =>
      'Sigue a intensidad moderada',
    ScreeningOutcome.stopAndSeekMedicalClearance =>
      'Detén el ejercicio y consulta a tu médico',
  };

  static String outcomeBody(ScreeningOutcome o) => switch (o) {
    ScreeningOutcome.clearedStartLightToModerate =>
      'Empieza con intensidad ligera a moderada y sube de forma gradual.',
    ScreeningOutcome.clearedContinue =>
      'Puedes seguir con tu nivel actual y progresar de forma gradual.',
    ScreeningOutcome.medicalClearanceBeforeStarting =>
      'Por tus respuestas, las guías del ACSM recomiendan autorización '
          'médica antes de empezar un programa de ejercicio.',
    ScreeningOutcome.medicalClearanceBeforeVigorous =>
      'Puedes seguir con ejercicio moderado. Para intensidad vigorosa, '
          'las guías recomiendan autorización médica.',
    ScreeningOutcome.stopAndSeekMedicalClearance =>
      'Reportaste síntomas que las guías del ACSM consideran señal de '
          'alerta. Suspende el ejercicio hasta tener autorización médica.',
  };

  static String progression(ProgressionDecision d) => switch (d.action) {
    ProgressionAction.increase =>
      'Toca subir: usa ${kg(d.nextLoadKg)} la próxima vez.',
    ProgressionAction.keep =>
      'Mantén ${kg(d.nextLoadKg)} hasta pasar el objetivo en 2 sesiones.',
    ProgressionAction.blockedByEquipment =>
      'Ya toca subir, pero el salto más chico de tu equipo pasa del 10 %. '
          'Usa discos más pequeños o suma repeticiones.',
  };

  static String kg(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} kg';

  static const hooperScale = [
    'Muy, muy bien',
    'Muy bien',
    'Bien',
    'Normal',
    'Mal',
    'Muy mal',
    'Muy, muy mal',
  ];

  static String goal(WeightGoal g) => switch (g) {
    WeightGoal.maintain => 'Mantener peso',
    WeightGoal.lose => 'Bajar de peso',
  };

  static String level(TrainingLevel l) => switch (l) {
    TrainingLevel.novice => 'Principiante',
    TrainingLevel.intermediate => 'Intermedio',
  };

  static String intensity(ActivityIntensity i) => switch (i) {
    ActivityIntensity.moderate => 'Moderada (puedes hablar)',
    ActivityIntensity.vigorous => 'Vigorosa (cuesta hablar)',
  };

  static String g(double v) => '${v.round()} g';

  static String pulseFailure(PulseFailure f) => switch (f) {
    PulseFailure.tooShort => 'La medición fue muy corta. Mantén el dedo 30 s.',
    PulseFailure.noFinger =>
      'No detecté el dedo. Cubre por completo la cámara y el flash.',
    PulseFailure.poorSignal =>
      'La señal salió irregular. Quédate quieto, sin presionar fuerte, y '
          'vuelve a intentar.',
  };
}
