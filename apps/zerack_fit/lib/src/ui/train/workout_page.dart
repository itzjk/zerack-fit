import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../services.dart';
import '../scope.dart';
import '../strings.dart';

/// Sesión guiada: series por ejercicio, temporizador de descanso, sugerencia
/// de carga y botón de alarma.
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required WorkoutTemplate this.template})
    : exercise = null;

  /// Un solo ejercicio fuera del plan.
  const WorkoutPage.single({super.key, required Exercise this.exercise})
    : template = null;

  final WorkoutTemplate? template;
  final Exercise? exercise;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  late final List<PlannedExercise> _planned;
  final Map<String, List<LoggedSet>> _sets = {};
  final _started = DateTime.now();
  int _current = 0;
  final _load = TextEditingController();
  final _reps = TextEditingController();
  Timer? _restTimer;
  Duration _restLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _planned =
        widget.template?.exercises ??
        [
          PlannedExercise(
            exercise: widget.exercise!,
            sets: 3,
            minReps: 8,
            maxReps: 12,
            rest: widget.exercise!.multiJoint
                ? const Duration(minutes: 2)
                : const Duration(seconds: 60),
          ),
        ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_load.text.isEmpty) _prefillLoad();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _load.dispose();
    _reps.dispose();
    super.dispose();
  }

  PlannedExercise get _p => _planned[_current];
  List<LoggedSet> get _done => _sets[_p.exercise.id] ?? const [];

  void _prefillLoad() {
    final e = _p.exercise;
    if (e.bodyweight) {
      _load.text = '0';
      return;
    }
    final d = AppScope.of(context).suggestionFor(e, targetReps: _p.targetReps);
    _load.text = d == null ? '' : Es.kg(d.nextLoadKg).replaceAll(' kg', '');
  }

  void _goTo(int i) {
    setState(() {
      _current = i;
      _reps.clear();
      _load.clear();
    });
    _prefillLoad();
  }

  void _startRest(Duration d) {
    _restTimer?.cancel();
    setState(() => _restLeft = d);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _restLeft -= const Duration(seconds: 1));
      if (_restLeft <= Duration.zero) {
        t.cancel();
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _addSet() {
    final load = _p.exercise.bodyweight
        ? 0.0
        : double.tryParse(_load.text.replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text);
    if (load == null || load < 0 || load > 1000 || reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el peso y las repeticiones')),
      );
      return;
    }
    setState(() {
      _sets
          .putIfAbsent(_p.exercise.id, () => [])
          .add(LoggedSet(loadKg: load, reps: reps));
      _reps.clear();
    });
    if (_done.length < _p.sets) _startRest(_p.rest);
  }

  Future<void> _finish() async {
    final state = AppScope.of(context);
    final health = ServicesScope.of(context).health;
    final minutes = DateTime.now().difference(_started).inMinutes.clamp(1, 600);
    await state.logWorkout(
      setsByExercise: _sets,
      minutes: minutes,
      templateId: widget.template?.id,
    );
    if (state.settings.healthSync && health.supported) {
      final kcal = activityKcal(
        met: Compendium.resistanceMultiple.met,
        weightKg: state.profile!.weightKg,
        duration: Duration(minutes: minutes),
      ).round();
      try {
        await health.writeWorkout(_started, DateTime.now(), kcal);
      } on Object {
        // La sincronización es opcional; el entreno ya quedó guardado.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _feelBad() async {
    final selected = await showDialog<Set<WarningSign>>(
      context: context,
      builder: (_) => const _WarningSignsDialog(),
    );
    if (selected == null || !mounted) return;
    if (evaluateSessionSafety(selected) ==
        SessionSafetyDecision.stopAndSeekCare) {
      _restTimer?.cancel();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          key: const Key('stop-dialog'),
          title: const Text('Detén el entrenamiento'),
          content: const Text(
            'Lo que sientes es una señal de alarma. Para ahora, siéntate y '
            'descansa. Si el síntoma no se quita o es fuerte, llama a '
            'emergencias (911 en México).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _p.exercise;
    final text = Theme.of(context).textTheme;
    final suggestion = AppScope.of(
      context,
    ).suggestionFor(e, targetReps: _p.targetReps);
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final anyDone = _sets.values.any((s) => s.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template?.name ?? e.name),
        actions: [
          TextButton(
            key: const Key('session-save'),
            onPressed: anyDone ? _finish : null,
            child: const Text('Terminar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_planned.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (i, p) in _planned.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${p.exercise.name} '
                          '${(_sets[p.exercise.id] ?? const []).length}/${p.sets}',
                        ),
                        selected: i == _current,
                        onSelected: (_) => _goTo(i),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(e.name, style: text.headlineSmall),
          Text(
            '${_p.sets} series × ${_p.minReps}–${_p.maxReps} '
            '${e.id == 'plank' ? 'segundos' : 'repeticiones'} · '
            'descanso ${_p.rest.inSeconds ~/ 60 > 0 ? '${_p.rest.inMinutes} min' : '${_p.rest.inSeconds} s'}',
          ),
          if (e.cue != null) Text(e.cue!, style: text.bodySmall),
          const SizedBox(height: 8),
          if (e.bodyweight)
            const Text(
              'Con peso corporal: cuando pases el rango, haz la '
              'variante más difícil.',
            )
          else
            Text(
              suggestion == null
                  ? 'Primera vez: elige un peso que puedas mover '
                        '${_p.maxReps} veces con buena técnica.'
                  : Es.progression(suggestion),
              key: const Key('progression-hint'),
            ),
          if (_restLeft > Duration.zero)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                key: const Key('rest-timer'),
                leading: const Icon(Icons.timer_outlined),
                title: Text(
                  'Descanso: ${_restLeft.inMinutes}:'
                  '${(_restLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                trailing: TextButton(
                  onPressed: () {
                    _restTimer?.cancel();
                    setState(() => _restLeft = Duration.zero);
                  },
                  child: const Text('Saltar'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!e.bodyweight) ...[
                Expanded(
                  child: TextField(
                    key: const Key('set-load'),
                    controller: _load,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: numeric,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  key: const Key('set-reps'),
                  controller: _reps,
                  decoration: InputDecoration(
                    labelText: e.id == 'plank' ? 'Segundos' : 'Repeticiones',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              IconButton.filled(
                key: const Key('set-add'),
                tooltip: 'Agregar serie',
                onPressed: _addSet,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, s) in _done.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(
                e.bodyweight ? '${s.reps}' : '${Es.kg(s.loadKg)} × ${s.reps}',
              ),
            ),
          if (_done.length >= _p.sets && _current < _planned.length - 1)
            FilledButton.tonal(
              key: const Key('next-exercise'),
              onPressed: () => _goTo(_current + 1),
              child: const Text('Siguiente ejercicio'),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('session-finish'),
            onPressed: anyDone ? _finish : null,
            child: const Text('Terminar entrenamiento'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('feel-bad'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.warning_amber),
            label: const Text('Me siento mal'),
            onPressed: _feelBad,
          ),
        ],
      ),
    );
  }
}

class _WarningSignsDialog extends StatefulWidget {
  const _WarningSignsDialog();

  @override
  State<_WarningSignsDialog> createState() => _WarningSignsDialogState();
}

class _WarningSignsDialogState extends State<_WarningSignsDialog> {
  final Set<WarningSign> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Qué sientes?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in WarningSign.values)
              CheckboxListTile(
                key: Key('feel-${s.name}'),
                value: _selected.contains(s),
                onChanged: (v) => setState(
                  () => v == true ? _selected.add(s) : _selected.remove(s),
                ),
                title: Text(Es.sign(s)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('feel-submit'),
          onPressed: () => Navigator.of(context).pop(Set.of(_selected)),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
