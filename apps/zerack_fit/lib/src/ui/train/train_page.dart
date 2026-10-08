import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../scope.dart';
import '../strings.dart';
import 'workout_page.dart';

class TrainPage extends StatelessWidget {
  const TrainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final screening = state.screening!;
    if (!screening.canTrain) return const _ClearanceGate();

    final next = state.nextWorkout;
    final plan = state.plan;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Entrenar', style: text.headlineSmall),
        if (!screening.outcome.allowsVigorous)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mantén una intensidad moderada: deberías poder hablar '
              'mientras haces la serie.',
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Toca hoy: ${next.name}', style: text.titleLarge),
                Text(
                  '${Es.level(plan.level)} · ${plan.daysPerWeek} días por '
                  'semana · ${next.exercises.length} ejercicios',
                ),
                const SizedBox(height: 8),
                for (final e in next.exercises)
                  Text(
                    '• ${e.exercise.name}: ${e.sets} × '
                    '${e.minReps}–${e.maxReps}',
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('workout-start'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Empezar entrenamiento'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkoutPage(template: next),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan de cuerpo completo según ACSM: 8–12 repeticiones, '
                  'descanso de 2 min en ejercicios grandes y 1 min en los '
                  'chicos, 48 h entre sesiones del mismo músculo.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            key: const Key('activity-add'),
            leading: const Icon(Icons.directions_walk),
            title: const Text('Anotar actividad'),
            subtitle: const Text('Caminar, bici, correr, nadar…'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _ActivityDialog(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Ejercicios sueltos', style: text.titleMedium),
        for (final e in exerciseCatalog)
          Card(
            child: ListTile(
              key: Key('exercise-${e.id}'),
              title: Text(e.name),
              subtitle: Text(_subtitle(state.suggestionFor(e), e)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutPage.single(exercise: e),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _subtitle(ProgressionDecision? d, Exercise e) {
    if (e.bodyweight) return 'Peso corporal: suma repeticiones';
    return d == null ? 'Objetivo: 8–12 repeticiones' : Es.progression(d);
  }
}

class _ClearanceGate extends StatelessWidget {
  const _ClearanceGate();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final outcome = state.screening!.outcome;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.medical_services_outlined, size: 64),
        const SizedBox(height: 16),
        Text(Es.outcomeTitle(outcome), style: text.headlineSmall),
        const SizedBox(height: 12),
        Text(Es.outcomeBody(outcome)),
        const SizedBox(height: 24),
        OutlinedButton(
          key: const Key('clearance-confirm'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Confirmar autorización'),
                content: const Text(
                  'Confirmo que un médico me autorizó a hacer ejercicio.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('clearance-yes'),
                    onPressed: () => Navigator.of(c).pop(true),
                    child: const Text('Sí, confirmo'),
                  ),
                ],
              ),
            );
            if (ok == true) await state.confirmClearance(true);
          },
          child: const Text('Ya tengo autorización médica'),
        ),
      ],
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog();

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _label = TextEditingController(text: 'Caminar');
  final _minutes = TextEditingController();
  ActivityIntensity _intensity = ActivityIntensity.moderate;

  @override
  void dispose() {
    _label.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final minutes = int.tryParse(_minutes.text);
    final valid = minutes != null && minutes > 0 && minutes <= 1440;
    final vigorousBlocked = !state.screening!.outcome.allowsVigorous;
    return AlertDialog(
      title: const Text('Anotar actividad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('activity-label'),
            controller: _label,
            decoration: const InputDecoration(labelText: 'Actividad'),
          ),
          TextField(
            key: const Key('activity-minutes'),
            controller: _minutes,
            decoration: const InputDecoration(labelText: 'Minutos'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          RadioGroup<ActivityIntensity>(
            groupValue: _intensity,
            onChanged: (v) => setState(() => _intensity = v ?? _intensity),
            child: Column(
              children: [
                for (final i in ActivityIntensity.values)
                  RadioListTile<ActivityIntensity>(
                    value: i,
                    enabled:
                        !(vigorousBlocked && i == ActivityIntensity.vigorous),
                    title: Text(Es.intensity(i)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('activity-save'),
          onPressed: valid
              ? () async {
                  await state.logActivity(_label.text, minutes, _intensity);
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
