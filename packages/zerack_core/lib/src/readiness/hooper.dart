import '../source.dart';

/// Cuestionario de Hooper (1995): cuatro ítems de 1 a 7, donde 1 es "muy,
/// muy bien" y 7 es "muy, muy mal".
class HooperAnswers {
  HooperAnswers({
    required this.sleep,
    required this.stress,
    required this.fatigue,
    required this.soreness,
  }) {
    for (final (name, v) in [
      ('sleep', sleep),
      ('stress', stress),
      ('fatigue', fatigue),
      ('soreness', soreness),
    ]) {
      if (v < 1 || v > 7) {
        throw RangeError.range(v, 1, 7, name);
      }
    }
  }

  final int sleep;
  final int stress;
  final int fatigue;
  final int soreness;

  /// Índice de Hooper: suma de los cuatro ítems (4 = mejor, 28 = peor).
  int get index => sleep + stress + fatigue + soreness;

  static const source = Sources.hooper1995;
}

/// Nota de 0 a 100 de cómo llega la persona hoy.
///
/// Es una transformación lineal del índice de Hooper (4 → 100, 28 → 0) para
/// mostrarlo en escala amigable. **No es un umbral validado**: la fuente
/// recomienda comparar a la persona contra sí misma, no contra cortes fijos.
int readinessScore(HooperAnswers a) => ((28 - a.index) / 24 * 100).round();
