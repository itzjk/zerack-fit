import '../source.dart';

enum MuscleGroup { legs, chest, back, shoulders, biceps, triceps, core }

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
    group: MuscleGroup.biceps,
    multiJoint: false,
    smallestStepKg: 1,
    cue: 'Codos quietos a los lados.',
  ),
  Exercise(
    id: 'triceps_pushdown',
    name: 'Extensión de tríceps en polea',
    group: MuscleGroup.triceps,
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
///
/// Frecuencias de ACSM 2009 (progresión en entrenamiento de fuerza):
/// principiante 2–3 días por semana, intermedio 3–4, avanzado 4–6 con rutinas
/// divididas.
enum TrainingLevel {
  novice(2, 3),
  intermediate(3, 4),
  advanced(4, 6);

  const TrainingLevel(this.minDays, this.maxDays);
  final int minDays;
  final int maxDays;

  bool allowsDays(int days) => days >= minDays && days <= maxDays;

  /// Ajusta [days] al rango permitido para este nivel.
  int clampDays(int days) => days.clamp(minDays, maxDays);

  static const source = Sources.acsmProgression2009;
}

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
    required this.schedule,
  });

  final TrainingLevel level;
  final int daysPerWeek;

  /// Sesiones distintas del plan.
  final List<WorkoutTemplate> workouts;

  /// Día de la semana (1 = lunes … 7 = domingo) → id de la sesión. Los días
  /// que no aparecen son de descanso.
  final Map<int, String> schedule;

  static const sources = [
    Sources.acsmProgression2009,
    Sources.acsmQuantity2011,
  ];

  WorkoutTemplate byId(String id) => workouts.firstWhere((w) => w.id == id);

  /// Sesión de ese día de la semana, o `null` si es descanso.
  WorkoutTemplate? forWeekday(int weekday) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday', '1 a 7');
    }
    final id = schedule[weekday];
    return id == null ? null : byId(id);
  }

  /// La semana completa de lunes a domingo.
  List<({int weekday, WorkoutTemplate? workout})> get week => [
        for (var d = 1; d <= 7; d++) (weekday: d, workout: forWeekday(d)),
      ];

  /// Próximo día con entreno a partir de [weekday] (incluido).
  ({int weekday, WorkoutTemplate workout}) nextFrom(int weekday) {
    for (var i = 0; i < 7; i++) {
      final d = (weekday - 1 + i) % 7 + 1;
      final w = forWeekday(d);
      if (w != null) return (weekday: d, workout: w);
    }
    throw StateError('plan sin días de entreno');
  }
}

/// Plan semanal según ACSM:
/// - Días por semana dentro del rango del nivel (ACSM 2009).
/// - 2–3 días: cuerpo completo A/B en días no consecutivos (≥48 h entre
///   sesiones del mismo grupo muscular, ACSM 2011).
/// - 4 días: tren superior / inferior (rutina dividida, ACSM 2009).
/// - 5–6 días: empuje / jalón / piernas (rutina dividida, ACSM 2009); cada
///   grupo muscular vuelve a trabajarse a las 72 h o más.
/// - 8–12 repeticiones (ACSM 2009 y 2011).
/// - Principiante 2 series (ACSM: 1–3); intermedio y avanzado 3 (múltiples).
/// - Descanso 2 min en multiarticulares y 60 s en los demás (extremo bajo de
///   ACSM 2009).
TrainingPlan buildWeeklyPlan({
  required TrainingLevel level,
  required int daysPerWeek,
  bool gymAccess = true,
}) {
  if (!level.allowsDays(daysPerWeek)) {
    throw ArgumentError.value(
      daysPerWeek,
      'daysPerWeek',
      'ACSM: ${level.minDays} a ${level.maxDays} para ${level.name}',
    );
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

  WorkoutTemplate t(
          String id, String name, List<String> gym, List<String> home) =>
      WorkoutTemplate(id, name, [for (final e in gymAccess ? gym : home) p(e)]);

  final fullA = t(
    'A',
    'Cuerpo completo A',
    ['back_squat', 'bench_press', 'lat_pulldown', 'dumbbell_curl', 'plank'],
    ['goblet_squat', 'pushup', 'barbell_row', 'dumbbell_curl', 'plank'],
  );
  final fullB = t(
    'B',
    'Cuerpo completo B',
    [
      'romanian_deadlift',
      'overhead_press',
      'seated_row',
      'leg_press',
      'triceps_pushdown',
    ],
    ['romanian_deadlift', 'overhead_press', 'goblet_squat', 'plank'],
  );
  final upper = t(
    'upper',
    'Tren superior',
    [
      'bench_press',
      'barbell_row',
      'overhead_press',
      'lat_pulldown',
      'dumbbell_curl',
      'triceps_pushdown',
    ],
    ['pushup', 'barbell_row', 'overhead_press', 'dumbbell_curl'],
  );
  final lower = t(
    'lower',
    'Tren inferior',
    ['back_squat', 'romanian_deadlift', 'leg_press', 'plank'],
    ['goblet_squat', 'romanian_deadlift', 'plank'],
  );
  final push = t(
    'push',
    'Empuje (pecho, hombro, tríceps)',
    ['bench_press', 'overhead_press', 'pushup', 'triceps_pushdown'],
    ['pushup', 'overhead_press'],
  );
  final pull = t(
    'pull',
    'Jalón (espalda, bíceps)',
    ['lat_pulldown', 'barbell_row', 'seated_row', 'dumbbell_curl'],
    ['barbell_row', 'dumbbell_curl'],
  );
  final legs = t(
    'legs',
    'Piernas y abdomen',
    ['back_squat', 'romanian_deadlift', 'leg_press', 'plank'],
    ['goblet_squat', 'romanian_deadlift', 'plank'],
  );

  final (workouts, schedule) = switch (daysPerWeek) {
    2 => ([fullA, fullB], {1: 'A', 4: 'B'}),
    3 => ([fullA, fullB], {1: 'A', 3: 'B', 5: 'A'}),
    4 => ([upper, lower], {1: 'upper', 2: 'lower', 4: 'upper', 5: 'lower'}),
    5 => (
        [push, pull, legs, upper, lower],
        {1: 'push', 2: 'pull', 3: 'legs', 4: 'upper', 5: 'lower'},
      ),
    _ => (
        [push, pull, legs],
        {1: 'push', 2: 'pull', 3: 'legs', 4: 'push', 5: 'pull', 6: 'legs'},
      ),
  };

  return TrainingPlan(
    level: level,
    daysPerWeek: daysPerWeek,
    workouts: workouts,
    schedule: schedule,
  );
}
