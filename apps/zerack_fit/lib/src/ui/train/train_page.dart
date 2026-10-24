import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../scope.dart';
import '../strings.dart';
import '../../data/models.dart' show weekdayNamesEs;
import '../theme/zerack_theme.dart';
import 'exercise_detail_page.dart';
import 'workout_page.dart';
import '../theme/zk_widgets.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  /// Día elegido (1 = lunes). `null` = hoy.
  int? _selected;

  static const _short = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final screening = state.screening!;
    if (!screening.canTrain) return const _ClearanceGate();

    final plan = state.plan;
    final today = state.now.weekday;
    final day = _selected ?? today;
    final workout = plan.forWeekday(day);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ZkPageTitle('Entrenar', eyebrow: 'Plan semanal'),
        Text(
          '${Es.level(plan.level)} · ${plan.daysPerWeek} días por semana'
          '${state.settings.gymAccess ? ' · gimnasio' : ' · en casa'}',
          style: text.bodyMedium,
        ),
        if (!screening.outcome.allowsVigorous)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mantén una intensidad moderada: deberías poder hablar '
              'mientras haces la serie.',
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final d in plan.week)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    key: Key('day-${d.weekday}'),
                    letter: _short[d.weekday - 1],
                    training: d.workout != null,
                    selected: d.weekday == day,
                    today: d.weekday == today,
                    onTap: () => setState(() => _selected = d.weekday),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekdayNamesEs[day - 1]}${day == today ? ' (hoy)' : ''}',
                  style: text.labelLarge,
                ),
                const SizedBox(height: 4),
                if (workout == null) ...[
                  Text(
                    'Descanso',
                    key: const Key('day-rest'),
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recuperarte también es parte del plan. Próximo '
                    'entreno: ${weekdayNamesEs[plan.nextFrom(day % 7 + 1).weekday - 1].toLowerCase()}.',
                  ),
                ] else ...[
                  Text(
                    workout.name,
                    key: const Key('day-workout'),
                    style: text.titleLarge,
                  ),
                  Text(
                    '${workout.exercises.length} ejercicios · toca uno para '
                    'verlo en movimiento',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  for (final e in workout.exercises)
                    ListTile(
                      key: Key('plan-exercise-${e.exercise.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(e.exercise.name),
                      subtitle: Text(
                        '${e.sets} × ${e.minReps}–${e.maxReps}'
                        '${e.exercise.id == 'plank' ? ' s' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        ExerciseDetailPage(exercise: e.exercise, planned: e),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('workout-start'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Empezar entrenamiento'),
                    onPressed: () => _open(WorkoutPage(template: workout)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Plan según ACSM: días por semana según tu nivel, 8–12 '
                  'repeticiones y 48 h o más antes de repetir el mismo '
                  'músculo. Cambia nivel y días en Perfil.',
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
        const ZkSectionLabel('Todos los ejercicios'),
        for (final e in exerciseCatalog)
          Card(
            child: ListTile(
              key: Key('exercise-${e.id}'),
              title: Text(e.name),
              subtitle: Text(_subtitle(state.suggestionFor(e), e)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(ExerciseDetailPage(exercise: e)),
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.letter,
    required this.training,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String letter;
  final bool training;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Zk.cyanSoft : Zk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Zk.cyan : (today ? Zk.cyanLine : Zk.hairlineStrong),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                letter,
                style: TextStyle(
                  color: selected ? Zk.cyanBright : Zk.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                training ? Icons.fitness_center : Icons.bedtime_outlined,
                size: 14,
                color: training ? Zk.cyan : Zk.faint,
              ),
            ],
          ),
        ),
      ),
    );
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
        const ZkHeroIcon(Icons.medical_services_outlined),
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
