import '../source.dart';

/// Una serie registrada de un ejercicio.
class LoggedSet {
  const LoggedSet({required this.loadKg, required this.reps});
  final double loadKg;
  final int reps;
}

/// Sesión de un ejercicio: todas las series hechas con la carga de trabajo.
class ExerciseSession {
  const ExerciseSession(this.sets);
  final List<LoggedSet> sets;

  /// Carga de trabajo de la sesión (la más alta usada).
  double get workingLoadKg =>
      sets.map((s) => s.loadKg).fold(0, (a, b) => a > b ? a : b);

  /// Repeticiones mínimas logradas entre las series con la carga de trabajo.
  int get minRepsAtWorkingLoad => sets
      .where((s) => s.loadKg == workingLoadKg)
      .map((s) => s.reps)
      .reduce((a, b) => a < b ? a : b);
}

/// Configuración de progresión para un ejercicio.
class ProgressionConfig {
  const ProgressionConfig({
    required this.targetReps,
    this.incrementFraction = 0.05,
    this.smallestStepKg = 2.5,
  }) : assert(incrementFraction >= 0.02 && incrementFraction <= 0.10,
            'ACSM 2009 recomienda incrementos de 2 a 10 %');

  /// Repeticiones objetivo por serie (p. ej. 10).
  final int targetReps;

  /// Fracción de aumento de carga (ACSM 2009: 0.02 a 0.10).
  final double incrementFraction;

  /// Salto más pequeño posible con el equipo disponible (discos, mancuernas).
  final double smallestStepKg;
}

enum ProgressionAction {
  increase,
  keep,

  /// Ya toca subir, pero el salto mínimo del equipo supera el 10 %. La UI
  /// debe sugerir discos más pequeños o más repeticiones.
  blockedByEquipment,
}

class ProgressionDecision {
  const ProgressionDecision(this.action, this.nextLoadKg);
  final ProgressionAction action;
  final double nextLoadKg;

  static const source = Sources.acsmProgression2009;
}

/// Regla "2 de más en 2 sesiones" de ACSM (2009): subir la carga 2–10 %
/// cuando la persona completa 1–2 repeticiones por encima del objetivo en
/// dos sesiones consecutivas con la misma carga.
///
/// No bajamos cargas automáticamente: la fuente no define esa regla y el
/// proyecto no inventa reglas sin respaldo.
ProgressionDecision decideProgression({
  required List<ExerciseSession> history,
  required ProgressionConfig config,
}) {
  if (history.isEmpty) {
    throw ArgumentError.value(history, 'history', 'no puede estar vacío');
  }
  final current = history.last.workingLoadKg;
  if (history.length < 2) {
    return ProgressionDecision(ProgressionAction.keep, current);
  }

  final lastTwo = history.sublist(history.length - 2);
  final sameLoad = lastTwo.every((s) => s.workingLoadKg == current);
  final exceeded =
      lastTwo.every((s) => s.minRepsAtWorkingLoad >= config.targetReps + 1);

  if (!sameLoad || !exceeded) {
    return ProgressionDecision(ProgressionAction.keep, current);
  }

  final next = _nextLoad(current, config);
  return next > current
      ? ProgressionDecision(ProgressionAction.increase, next)
      : ProgressionDecision(ProgressionAction.blockedByEquipment, current);
}

double _nextLoad(double current, ProgressionConfig c) {
  final step = c.smallestStepKg;
  final raw = current * (1 + c.incrementFraction);
  final rounded = (raw / step).round() * step;
  if (rounded > current && rounded <= current * 1.10 + 1e-9) return rounded;
  // Si redondear deja la carga igual, probamos el salto mínimo, siempre que no
  // pase del 10 % que permite la fuente.
  final minimal = current + step;
  return minimal <= current * 1.10 + 1e-9 ? minimal : current;
}
