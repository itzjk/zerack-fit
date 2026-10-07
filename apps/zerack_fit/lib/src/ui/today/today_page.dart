import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../scope.dart';
import '../strings.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [_ReadinessCard(), SizedBox(height: 16), _EnergyCard()],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    final checkIn = AppScope.of(context).todayCheckIn;
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
            FilledButton.tonal(
              key: const Key('checkin-open'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CheckInPage()),
              ),
              child: Text(
                checkIn == null ? 'Hacer chequeo' : 'Repetir chequeo',
              ),
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile!;
    final range = energyRange(profile.totalKcal);
    final eaten = state.todayKcalEaten;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Energía de hoy', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Gastas aprox. ${range.low.round()}–${range.high.round()} kcal',
              key: const Key('energy-range'),
              style: text.titleMedium,
            ),
            const Text(
              'Estimación con Mifflin-St Jeor y tu nivel de actividad '
              '(FAO 2004). Margen típico ±10 %.',
            ),
            const Divider(height: 32),
            Text(
              'Comiste $eaten kcal',
              key: const Key('energy-eaten'),
              style: text.titleMedium,
            ),
            for (final f in state.todayFood)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.label.isEmpty ? 'Comida' : f.label),
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
            OutlinedButton.icon(
              key: const Key('food-add'),
              icon: const Icon(Icons.add),
              label: const Text('Anotar comida'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _FoodDialog(),
              ),
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
      title: const Text('Anotar comida'),
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
