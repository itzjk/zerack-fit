import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../data/app_state.dart';
import '../../data/workout_draft.dart';
import '../../services.dart';
import '../scope.dart';
import '../strings.dart';
import '../theme/zerack_theme.dart';

/// Sesión guiada: series por ejercicio, temporizador de descanso, sugerencia
/// de carga y botón de alarma.
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required WorkoutTemplate this.template})
    : exercise = null;

  /// Un solo ejercicio fuera del plan.
  const WorkoutPage.single({super.key, required Exercise this.exercise})
    : template = null;

  const WorkoutPage.resume({super.key}) : template = null, exercise = null;

  final WorkoutTemplate? template;
  final Exercise? exercise;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  late final List<PlannedExercise> _planned;
  final Map<String, List<LoggedSet>> _sets = {};
  late final DateTime _started;
  late final String _name;
  String? _templateId;
  late AppState _state;
  bool _initialized = false;
  bool _busy = false;
  DateTime? _restUntil;
  int _current = 0;
  final _load = TextEditingController();
  final _reps = TextEditingController();
  Timer? _restTimer;
  Duration _restLeft = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _state = AppScope.of(context);
    final draft = _state.workoutDraft;
    _planned =
        draft?.planned ??
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
    _started = draft?.startedAt ?? _state.now;
    _name = draft?.name ?? widget.template?.name ?? widget.exercise!.name;
    _templateId = draft != null ? draft.templateId : widget.template?.id;
    if (draft != null) {
      for (final entry in draft.sets.entries) {
        _sets[entry.key] = List.of(entry.value);
      }
      _current = draft.current;
      _restUntil = draft.restUntil;
      _updateRest();
    }
    _prefillLoad();
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
    final done = _sets[e.id];
    if (done != null && done.isNotEmpty) {
      _load.text = Es.kg(done.last.loadKg).replaceAll(' kg', '');
      return;
    }
    final d = _state.suggestionFor(e, targetReps: _p.targetReps);
    _load.text = d == null ? '' : Es.kg(d.nextLoadKg).replaceAll(' kg', '');
  }

  WorkoutDraft _snapshot({
    Map<String, List<LoggedSet>>? sets,
    int? current,
    DateTime? restUntil,
  }) => WorkoutDraft(
    startedAt: _started,
    name: _name,
    templateId: _templateId,
    planned: _planned,
    sets: sets ?? _sets,
    current: current ?? _current,
    restUntil: restUntil,
  );

  Future<bool> _saveDraft(WorkoutDraft draft) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await _state.saveWorkoutDraft(draft);
      return true;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set not saved. Please try again.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goTo(int i) async {
    if (_busy) return;
    if (_sets.values.any((s) => s.isNotEmpty)) {
      if (!await _saveDraft(_snapshot(current: i, restUntil: _restUntil))) {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _current = i;
      _reps.clear();
      _load.clear();
    });
    _prefillLoad();
  }

  void _updateRest() {
    _restTimer?.cancel();
    Duration remaining() {
      final left = _restUntil?.difference(_state.now) ?? Duration.zero;
      return left.isNegative ? Duration.zero : left;
    }

    _restLeft = remaining();
    if (_restLeft == Duration.zero) return;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _restLeft = remaining());
      if (_restLeft == Duration.zero) {
        timer.cancel();
        HapticFeedback.mediumImpact();
      }
    });
  }

  Future<void> _skipRest() async {
    if (!await _saveDraft(_snapshot())) return;
    if (!mounted) return;
    _restTimer?.cancel();
    setState(() {
      _restUntil = null;
      _restLeft = Duration.zero;
    });
  }

  Future<void> _addSet() async {
    if (_busy) return;
    final load = _p.exercise.bodyweight
        ? 0.0
        : double.tryParse(_load.text.replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text);
    if (load == null ||
        !load.isFinite ||
        load < 0 ||
        load > 1000 ||
        reps == null ||
        reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el peso y las repeticiones')),
      );
      return;
    }
    final sets = {
      ..._sets,
      _p.exercise.id: [..._done, LoggedSet(loadKg: load, reps: reps)],
    };
    final restUntil = sets[_p.exercise.id]!.length < _p.sets
        ? _state.now.add(_p.rest)
        : null;
    if (!await _saveDraft(_snapshot(sets: sets, restUntil: restUntil))) return;
    if (!mounted) return;
    setState(() {
      _sets
        ..clear()
        ..addAll(sets);
      _reps.clear();
      _restUntil = restUntil;
      _updateRest();
    });
  }

  Future<void> _finish() async {
    if (_busy) return;
    final health = ServicesScope.of(context).health;
    setState(() => _busy = true);
    try {
      final saved = await _state.finishWorkoutDraft();
      if (!saved) return;
      if (_state.settings.healthSync && health.supported) {
        final kcal = activityKcal(
          met: Compendium.resistanceMultiple.met,
          weightKg: _state.profile!.weightKg,
          duration: Duration(minutes: _state.workouts.last.minutes),
        ).round();
        try {
          await health.writeWorkout(_started, _state.now, kcal);
        } on Object {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Workout saved locally. Health sync failed.'),
              ),
            );
          }
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Workout not finished. Your saved sets are safe. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      try {
        await _state.discardWorkoutDraft();
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not clear the stopped session. Do not resume training.',
              ),
            ),
          );
        }
      }
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
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_name),
          actions: [
            TextButton(
              key: const Key('session-save'),
              onPressed: anyDone && !_busy ? _finish : null,
              child: const Text('Terminar'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _busy
                  ? 'Saving locally...'
                  : anyDone
                  ? 'Sets saved on this device. You can leave and resume.'
                  : 'Each set is saved when you add it.',
              key: const Key('workout-save-status'),
              style: text.bodySmall,
            ),
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
                          onSelected: _busy ? null : (_) => _goTo(i),
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
                    onPressed: _busy ? null : _skipRest,
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
                      enabled: !_busy,
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
                    enabled: !_busy,
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
                  onPressed: _busy ? null : _addSet,
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
              FilledButton(
                key: const Key('next-exercise'),
                style: ZerackTheme.accentStyle,
                onPressed: _busy ? null : () => _goTo(_current + 1),
                child: const Text('Siguiente ejercicio'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('session-finish'),
              onPressed: anyDone && !_busy ? _finish : null,
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
              onPressed: _busy ? null : _feelBad,
            ),
          ],
        ),
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
