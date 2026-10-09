import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/exercises.dart';
import '../../data/models.dart';
import '../../services.dart';
import '../common/text_prompt.dart';
import '../scope.dart';
import '../strings.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final workouts = state.workouts.reversed.take(20).toList();
    final pulses = state.pulses.reversed.take(10).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Progreso', style: text.headlineSmall),
        const _WeightCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entrenamientos', style: text.titleLarge),
                const SizedBox(height: 8),
                if (workouts.isEmpty)
                  const Text('Todavía no registras entrenamientos.')
                else
                  for (final w in workouts)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fitness_center),
                      title: Text(
                        w.templateId == null
                            ? 'Ejercicio suelto'
                            : 'Cuerpo completo ${w.templateId}',
                      ),
                      subtitle: Text('${w.day} · ${w.minutes} min'),
                    ),
              ],
            ),
          ),
        ),
        const _StrengthCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pulso en reposo', style: text.titleLarge),
                const SizedBox(height: 8),
                if (pulses.isEmpty)
                  const Text('Mide tu pulso desde la pantalla Hoy.')
                else
                  for (final p in pulses)
                    Text('${dayKey(p.at)}  ${p.bpm.round()} lpm (estimado)'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard();

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    final health = ServicesScope.of(context).health;
    final raw = await showTextPrompt(
      context,
      title: 'Peso de hoy',
      initial: state.profile?.weightKg.toString(),
      suffix: 'kg',
      decimal: true,
      fieldKey: const Key('weight-input'),
      confirmKey: const Key('weight-save'),
    );
    final kg = double.tryParse(raw?.replaceAll(',', '.') ?? '');
    if (kg == null || !context.mounted) return;
    try {
      await state.logWeight(kg);
      if (state.settings.healthSync && health.supported) {
        await health.writeWeight(kg, DateTime.now());
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso fuera de rango (25–350 kg)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final weights = state.weights;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final first = weights.isEmpty ? null : parseDayKey(weights.first.day);
    final ys = [for (final w in weights) w.kg];
    final lo = ys.isEmpty ? 0.0 : ys.reduce((a, b) => a < b ? a : b);
    final hi = ys.isEmpty ? 0.0 : ys.reduce((a, b) => a > b ? a : b);
    // Rango redondeado a un intervalo "bonito" para que las etiquetas del eje
    // no se encimen con el mínimo y el máximo.
    final interval = _niceInterval(hi - lo);
    final minY = (lo / interval).floor() * interval;
    final maxY = ((hi / interval).ceil() * interval).clamp(
      minY + interval,
      double.infinity,
    );
    final spots = [
      for (final w in weights)
        FlSpot(parseDayKey(w.day).difference(first!).inDays.toDouble(), w.kg),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Peso', style: text.titleLarge)),
                TextButton.icon(
                  key: const Key('weight-add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar'),
                  onPressed: () => _add(context),
                ),
              ],
            ),
            if (weights.isNotEmpty)
              Text(
                'Último: ${Es.kg(weights.last.kg)} (${weights.last.day})',
                key: const Key('weight-last'),
              ),
            const SizedBox(height: 12),
            if (spots.length < 2)
              const Text(
                'Registra tu peso al menos dos días para ver la gráfica.',
              )
            else
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY.toDouble(),
                    gridData: FlGridData(horizontalInterval: interval),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: interval,
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        color: scheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carga máxima reciente por ejercicio.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final e in exerciseCatalog) {
      if (e.bodyweight) continue;
      final s = state.sessionsFor(e.id);
      if (s.isEmpty) continue;
      final first = s.first.asSession.workingLoadKg;
      final last = s.last.asSession.workingLoadKg;
      rows.add(
        Text(
          '${e.name}: ${Es.kg(first)} → ${Es.kg(last)} '
          '(${s.length} ${s.length == 1 ? 'sesión' : 'sesiones'})',
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuerza', style: text.titleLarge),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('Aquí verás cómo suben tus pesos.')
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}

/// 0.5, 1, 2 o 5 kg según el rango, para 2–6 líneas en la gráfica.
double _niceInterval(double range) {
  for (final i in [0.5, 1.0, 2.0, 5.0]) {
    if (range / i <= 5) return i;
  }
  return 10;
}
