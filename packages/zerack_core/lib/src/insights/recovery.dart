import '../source.dart';
import '../training/routine.dart';

/// Estado de recuperación de un grupo muscular.
enum RecoveryStatus {
  /// Nunca entrenado en el periodo revisado.
  fresh,

  /// Pasaron 48 h o más desde la última sesión: listo para volver a entrenar.
  ready,

  /// Menos de 48 h desde la última sesión.
  recovering,
}

class MuscleRecovery {
  const MuscleRecovery({
    required this.group,
    required this.status,
    this.lastTrained,
    this.setsLast7Days = 0,
  });

  final MuscleGroup group;
  final RecoveryStatus status;

  /// Día de la última sesión (sin hora).
  final DateTime? lastTrained;

  /// Series registradas en los últimos 7 días.
  final int setsLast7Days;

  /// Día desde el que vuelve a estar listo.
  DateTime? get readyOn => lastTrained?.add(minRest);

  /// ACSM 2011: al menos 48 h entre sesiones del mismo grupo muscular.
  static const minRest = Duration(hours: 48);
  static const source = Sources.acsmQuantity2011;
}

/// Una serie registrada de un ejercicio en un día.
class TrainedSet {
  const TrainedSet({required this.exerciseId, required this.day});
  final String exerciseId;
  final DateTime day;
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Recuperación por grupo muscular a partir de lo registrado.
///
/// Trabaja por días (los registros no guardan la hora): una sesión del lunes
/// queda lista el miércoles. El abdomen (`core`) se omite del aviso porque la
/// guía no lo restringe igual, pero sí se reporta.
List<MuscleRecovery> muscleRecovery(
  Iterable<TrainedSet> sets,
  DateTime now,
) {
  final today = _dateOnly(now);
  final weekStart = today.subtract(const Duration(days: 6));
  final last = <MuscleGroup, DateTime>{};
  final count = <MuscleGroup, int>{};
  for (final s in sets) {
    final Exercise e;
    try {
      e = exerciseById(s.exerciseId);
    } on ArgumentError {
      continue;
    }
    final d = _dateOnly(s.day);
    if (d.isAfter(today)) continue;
    final prev = last[e.group];
    if (prev == null || d.isAfter(prev)) last[e.group] = d;
    if (!d.isBefore(weekStart)) count[e.group] = (count[e.group] ?? 0) + 1;
  }
  return [
    for (final g in MuscleGroup.values)
      MuscleRecovery(
        group: g,
        lastTrained: last[g],
        setsLast7Days: count[g] ?? 0,
        status: switch (last[g]) {
          null => RecoveryStatus.fresh,
          final d when today.difference(d) >= MuscleRecovery.minRest =>
            RecoveryStatus.ready,
          _ => RecoveryStatus.recovering,
        },
      ),
  ];
}

/// Grupos de [workout] que todavía no cumplen las 48 h (sin contar abdomen).
Set<MuscleGroup> conflictsWith(
  WorkoutTemplate workout,
  List<MuscleRecovery> recovery,
) {
  final recovering = {
    for (final r in recovery)
      if (r.status == RecoveryStatus.recovering && r.group != MuscleGroup.core)
        r.group,
  };
  return {
    for (final e in workout.exercises)
      if (recovering.contains(e.exercise.group)) e.exercise.group,
  };
}
