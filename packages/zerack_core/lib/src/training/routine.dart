import '../source.dart';

enum MuscleGroup { legs, chest, back, shoulders, arms, core }

/// Ejercicio del catálogo base. El `id` es estable: los registros lo guardan.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.group,
    required this.multiJoint,
    this.smallestStepKg = 2.5,
    this.bodyweight = false,
    this.cue,
  });

  final String id;
  final String name;
  final MuscleGroup group;

  /// Multiarticular (sentadilla, press) o monoarticular (curl).
  final bool multiJoint;
  final double smallestStepKg;

  /// Se hace con el peso del cuerpo; la progresión es por repeticiones.
  final bool bodyweight;

  /// Indicación breve de técnica.
  final String? cue;
}

const exerciseCatalog = <Exercise>[
  Exercise(
    id: 'goblet_squat',
    name: 'Sentadilla goblet',
    group: MuscleGroup.legs,
    multiJoint: true,
    smallestStepKg: 2,
    cue: 'Pecho arriba, rodillas en línea con los pies.',
  ),
  Exercise(
    id: 'back_squat',
    name: 'Sentadilla con barra',
    group: MuscleGroup.legs,
    multiJoint: true,
    cue: 'Baja controlado hasta donde mantengas la espalda neutra.',
  ),
  Exercise(
    id: 'leg_press',
    name: 'Prensa de piernas',
    group: MuscleGroup.legs,
    multiJoint: true,
    smallestStepKg: 5,
    cue: 'No despegues la cadera del respaldo.',
  ),
  Exercise(
    id: 'romanian_deadlift',
    name: 'Peso muerto rumano',
    group: MuscleGroup.legs,
    multiJoint: true,
    cue: 'Cadera atrás, barra pegada a las piernas, espalda neutra.',
  ),
  Exercise(
    id: 'bench_press',
    name: 'Press de banca',
    group: MuscleGroup.chest,
    multiJoint: true,
    cue: 'Escápulas juntas, la barra baja a media altura del pecho.',
  ),
  Exercise(
    id: 'pushup',
    name: 'Lagartijas',
    group: MuscleGroup.chest,
    multiJoint: true,
    bodyweight: true,
    cue: 'Cuerpo en línea recta; apoya rodillas si hace falta.',
  ),
  Exercise(
    id: 'lat_pulldown',
    name: 'Jalón al pecho',
    group: MuscleGroup.back,
    multiJoint: true,
    cue: 'Lleva la barra a la clavícula sin balancearte.',
  ),
  Exercise(
    id: 'barbell_row',
    name: 'Remo con barra',
    group: MuscleGroup.back,
    multiJoint: true,
    cue: 'Torso inclinado y firme, jala hacia el ombligo.',
  ),
  Exercise(
    id: 'seated_row',
    name: 'Remo sentado en polea',
    group: MuscleGroup.back,
    multiJoint: true,
    smallestStepKg: 5,
    cue: 'Espalda recta, junta las escápulas al final.',
  ),
  Exercise(
    id: 'overhead_press',
    name: 'Press militar',
    group: MuscleGroup.shoulders,
    multiJoint: true,
    cue: 'Abdomen firme, no arquees la espalda baja.',
  ),
  Exercise(
    id: 'dumbbell_curl',
    name: 'Curl con mancuernas',
    group: MuscleGroup.arms,
    multiJoint: false,
    smallestStepKg: 1,
    cue: 'Codos quietos a los lados.',
  ),
  Exercise(
    id: 'triceps_pushdown',
    name: 'Extensión de tríceps en polea',
    group: MuscleGroup.arms,
    multiJoint: false,
    smallestStepKg: 2.5,
    cue: 'Codos pegados, extiende por completo.',
  ),
  Exercise(
    id: 'plank',
    name: 'Plancha (segundos)',
    group: MuscleGroup.core,
    multiJoint: false,
    bodyweight: true,
    cue: 'Cadera alineada; anota los segundos como repeticiones.',
  ),
];

Exercise exerciseById(String id) => exerciseCatalog.firstWhere(
      (e) => e.id == id,
      orElse: () =>
          throw ArgumentError.value(id, 'id', 'ejercicio desconocido'),
    );

/// Experiencia de entrenamiento de fuerza.
enum TrainingLevel { novice, intermediate }

class PlannedExercise {
  const PlannedExercise({
    required this.exercise,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.rest,
  });

  final Exercise exercise;
  final int sets;
  final int minReps;
  final int maxReps;
  final Duration rest;

  /// Objetivo para la regla de progresión: el tope del rango.
  int get targetReps => maxReps;
}

class WorkoutTemplate {
  const WorkoutTemplate(this.id, this.name, this.exercises);
  final String id;
  final String name;
  final List<PlannedExercise> exercises;
}

class TrainingPlan {
  const TrainingPlan({
    required this.level,
    required this.daysPerWeek,
    required this.workouts,
  });

  final TrainingLevel level;
  final int daysPerWeek;

  /// Sesiones que se alternan (A, B, A, B...).
  final List<WorkoutTemplate> workouts;

  static const sources = [
    Sources.acsmProgression2009,
    Sources.acsmQuantity2011
  ];

  /// Sesión que toca después de [completedSessions] sesiones terminadas.
  WorkoutTemplate next(int completedSessions) =>
      workouts[completedSessions % workouts.length];
}

/// Plan de cuerpo completo según ACSM:
/// - 2–3 días por semana (ACSM 2009 para principiantes; ACSM 2011 para
///   adultos sanos, con ≥48 h entre sesiones del mismo grupo muscular).
/// - 8–12 repeticiones (ACSM 2009 y 2011).
/// - Principiante 1–3 series (usamos 2); intermedio series múltiples (3).
/// - Descanso 2–3 min en multiarticulares pesados y 1–2 min en los demás
///   (ACSM 2009); usamos el extremo bajo de cada rango.
TrainingPlan buildFullBodyPlan({
  required TrainingLevel level,
  required int daysPerWeek,
  bool gymAccess = true,
}) {
  if (daysPerWeek < 2 || daysPerWeek > 3) {
    throw ArgumentError.value(daysPerWeek, 'daysPerWeek', 'ACSM: 2 a 3');
  }
  final sets = level == TrainingLevel.novice ? 2 : 3;

  PlannedExercise p(String id) {
    final e = exerciseById(id);
    final isPlank = id == 'plank';
    return PlannedExercise(
      exercise: e,
      sets: sets,
      minReps: isPlank ? 20 : 8,
      maxReps: isPlank ? 40 : 12,
      rest: e.multiJoint
          ? const Duration(minutes: 2)
          : const Duration(seconds: 60),
    );
  }

  final a = gymAccess
      ? ['back_squat', 'bench_press', 'lat_pulldown', 'dumbbell_curl', 'plank']
      : ['goblet_squat', 'pushup', 'barbell_row', 'dumbbell_curl', 'plank'];
  final b = gymAccess
      ? [
          'romanian_deadlift',
          'overhead_press',
          'seated_row',
          'leg_press',
          'triceps_pushdown',
        ]
      : ['romanian_deadlift', 'overhead_press', 'goblet_squat', 'plank'];

  return TrainingPlan(
    level: level,
    daysPerWeek: daysPerWeek,
    workouts: [
      WorkoutTemplate('A', 'Cuerpo completo A', [for (final id in a) p(id)]),
      WorkoutTemplate('B', 'Cuerpo completo B', [for (final id in b) p(id)]),
    ],
  );
}
