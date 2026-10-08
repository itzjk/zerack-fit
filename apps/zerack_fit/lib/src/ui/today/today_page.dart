import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../data/models.dart';
import '../common/portion_sheet.dart';
import '../food/barcode_page.dart';
import '../food/food_search_page.dart';
import '../food/scan_page.dart';
import '../pulse/pulse_page.dart';
import '../scope.dart';
import '../strings.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [_ReadinessCard(), _EnergyCard(), _WeekCard()],
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final checkIn = state.todayCheckIn;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cómo llegas hoy?', style: text.titleLarge),
            const SizedBox(height: 8),
            if (checkIn == null)
              const Text('Haz tu chequeo de 4 preguntas antes de entrenar.')
            else ...[
              Text(
                '${checkIn.score}',
                key: const Key('readiness-score'),
                style: text.displayMedium,
              ),
              const Text(
                'Escala de 0 a 100 basada en el cuestionario de Hooper. '
                'Compárala con tus propios días, no con otras personas.',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  key: const Key('checkin-open'),
                  onPressed: () => _push(context, const CheckInPage()),
                  child: Text(
                    checkIn == null ? 'Hacer chequeo' : 'Repetir chequeo',
                  ),
                ),
                if (!kIsWeb)
                  OutlinedButton.icon(
                    key: const Key('pulse-open'),
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Medir pulso'),
                    onPressed: () => _push(context, const PulsePage()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final Map<String, int> _values = {
    'sleep': 4,
    'stress': 4,
    'fatigue': 4,
    'soreness': 4,
  };

  static const _labels = {
    'sleep': 'Calidad de tu sueño anoche',
    'stress': 'Nivel de estrés',
    'fatigue': 'Cansancio',
    'soreness': 'Dolor muscular',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chequeo del día')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final key in _values.keys) ...[
            Text(_labels[key]!, style: Theme.of(context).textTheme.titleMedium),
            Slider(
              key: Key('hooper-$key'),
              value: _values[key]!.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: Es.hooperScale[_values[key]! - 1],
              onChanged: (v) => setState(() => _values[key] = v.round()),
            ),
            Text(Es.hooperScale[_values[key]! - 1]),
            const SizedBox(height: 16),
          ],
          FilledButton(
            key: const Key('checkin-save'),
            onPressed: () async {
              await AppScope.of(context).saveCheckIn(
                HooperAnswers(
                  sleep: _values['sleep']!,
                  stress: _values['stress']!,
                  fatigue: _values['fatigue']!,
                  soreness: _values['soreness']!,
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard();

  static String _sourceLabel(FoodSource s) => switch (s) {
    FoodSource.manual => 'a mano',
    FoodSource.usda => 'USDA',
    FoodSource.openFoodFacts => 'Open Food Facts',
    FoodSource.scan => 'foto + USDA',
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile!;
    final target = state.energyTarget!;
    final range = energyRange(target.kcal);
    final eaten = state.todayNutrients;
    final protein = state.proteinRange!;
    final text = Theme.of(context).textTheme;
    final progress = (eaten.kcal / target.kcal).clamp(0.0, 1.0);
    final remaining = (target.kcal - eaten.kcal).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comida de hoy', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${Es.goal(state.settings.goal)}: '
              'meta de ${target.kcal.round()} kcal',
              key: const Key('energy-target'),
              style: text.titleMedium,
            ),
            Text(
              'Rango estimado ${range.low.round()}–${range.high.round()} kcal '
              '(Mifflin-St Jeor ±10 %, actividad FAO 2004'
              '${state.settings.goal == WeightGoal.lose ? ', −500 kcal ACSM' : ''}).',
              key: const Key('energy-range'),
              style: text.bodySmall,
            ),
            if (target.limitedByResting)
              Text(
                'Tu meta no baja de tu gasto en reposo '
                '(${profile.restingKcal.round()} kcal).',
                style: text.bodySmall,
              ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              'Comiste ${eaten.kcal.round()} kcal · '
              '${remaining >= 0 ? 'te quedan $remaining' : 'te pasaste ${-remaining}'}',
              key: const Key('energy-eaten'),
            ),
            const SizedBox(height: 12),
            NutrientRow(eaten),
            const SizedBox(height: 4),
            Text(
              'Proteína recomendada: ${protein.minG.round()}–'
              '${protein.maxG.round()} g al día (ISSN 2017).',
              style: text.bodySmall,
            ),
            const Divider(height: 24),
            for (final f in state.todayFood)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(f.label.isEmpty ? 'Comida' : f.label),
                subtitle: Text(
                  [
                    if (f.grams != null) '${f.grams!.round()} g',
                    _sourceLabel(f.source),
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${f.kcal} kcal'),
                    IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.close),
                      onPressed: () => state.removeFood(f),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('food-scan'),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Escanear plato'),
                  onPressed: () => _push(context, const ScanPage()),
                ),
                OutlinedButton.icon(
                  key: const Key('food-search-open'),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  onPressed: () => _push(context, const FoodSearchPage()),
                ),
                if (!kIsWeb)
                  OutlinedButton.icon(
                    key: const Key('food-barcode'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Código'),
                    onPressed: () => _push(context, const BarcodePage()),
                  ),
                TextButton.icon(
                  key: const Key('food-add'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('A mano'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _FoodDialog(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodDialog extends StatefulWidget {
  const _FoodDialog();

  @override
  State<_FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<_FoodDialog> {
  final _label = TextEditingController();
  final _kcal = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _kcal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kcal = int.tryParse(_kcal.text);
    final valid = kcal != null && kcal > 0 && kcal <= 10000;
    return AlertDialog(
      title: const Text('Anotar a mano'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('food-label'),
            controller: _label,
            decoration: const InputDecoration(labelText: 'Qué comiste'),
          ),
          TextField(
            key: const Key('food-kcal'),
            controller: _kcal,
            decoration: const InputDecoration(labelText: 'Calorías (kcal)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('food-save'),
          onPressed: valid
              ? () async {
                  await AppScope.of(context).addFood(_label.text, kcal);
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final w = AppScope.of(context).weekSummary;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Últimos 7 días', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${w.moderateEquivalentMinutes} de '
              '${WeeklySummary.aerobicMinimum} min de actividad',
              key: const Key('week-minutes'),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: w.aerobicProgress, minHeight: 6),
            const SizedBox(height: 8),
            Text(
              '${w.strengthDays} de ${WeeklySummary.strengthDaysMinimum} días '
              'de fuerza ${w.meetsStrength ? '✓' : ''}',
            ),
            const SizedBox(height: 4),
            Text(
              'Recomendación OMS 2020: 150–300 min moderados por semana (los '
              'vigorosos cuentan doble) y fuerza 2 días o más.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
