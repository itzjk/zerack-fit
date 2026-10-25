import 'package:zerack_core/zerack_core.dart';

class WorkoutDraft {
  WorkoutDraft({
    required this.startedAt,
    required this.name,
    required List<PlannedExercise> planned,
    required Map<String, List<LoggedSet>> sets,
    this.templateId,
    this.current = 0,
    this.restUntil,
  }) : planned = List.unmodifiable(planned),
       sets = Map.unmodifiable({
         for (final entry in sets.entries)
           entry.key: List<LoggedSet>.unmodifiable(entry.value),
       }) {
    if (planned.isEmpty || current < 0 || current >= planned.length) {
      throw const FormatException('Invalid workout position');
    }
    final ids = planned.map((p) => p.exercise.id).toSet();
    if (ids.length != planned.length ||
        sets.keys.any((id) => !ids.contains(id))) {
      throw const FormatException('Invalid workout exercises');
    }
    for (final set in sets.values.expand((s) => s)) {
      if (!set.loadKg.isFinite ||
          set.loadKg < 0 ||
          set.loadKg > 1000 ||
          set.reps < 1) {
        throw const FormatException('Invalid workout set');
      }
    }
  }

  final DateTime startedAt;
  final String name;
  final String? templateId;
  final List<PlannedExercise> planned;
  final Map<String, List<LoggedSet>> sets;
  final int current;
  final DateTime? restUntil;

  int get setCount => sets.values.fold(0, (n, s) => n + s.length);

  Duration restRemaining(DateTime now) {
    final left = restUntil?.difference(now) ?? Duration.zero;
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'name': name,
    'templateId': templateId,
    'current': current,
    'restUntil': restUntil?.toIso8601String(),
    'planned': [
      for (final p in planned)
        {
          'exerciseId': p.exercise.id,
          'sets': p.sets,
          'minReps': p.minReps,
          'maxReps': p.maxReps,
          'restSeconds': p.rest.inSeconds,
        },
    ],
    'sets': {
      for (final entry in sets.entries)
        entry.key: [
          for (final s in entry.value) {'loadKg': s.loadKg, 'reps': s.reps},
        ],
    },
  };

  factory WorkoutDraft.fromJson(Map<String, Object?> j) => WorkoutDraft(
    startedAt: DateTime.parse(j['startedAt'] as String),
    name: j['name'] as String,
    templateId: j['templateId'] as String?,
    current: j['current'] as int,
    restUntil: j['restUntil'] == null
        ? null
        : DateTime.parse(j['restUntil'] as String),
    planned: [
      for (final p in (j['planned'] as List).cast<Map<String, Object?>>())
        PlannedExercise(
          exercise: exerciseById(p['exerciseId'] as String),
          sets: p['sets'] as int,
          minReps: p['minReps'] as int,
          maxReps: p['maxReps'] as int,
          rest: Duration(seconds: p['restSeconds'] as int),
        ),
    ],
    sets: {
      for (final entry in (j['sets'] as Map<String, Object?>).entries)
        entry.key: [
          for (final s in (entry.value as List).cast<Map<String, Object?>>())
            LoggedSet(
              loadKg: (s['loadKg'] as num).toDouble(),
              reps: s['reps'] as int,
            ),
        ],
    },
  );
}
