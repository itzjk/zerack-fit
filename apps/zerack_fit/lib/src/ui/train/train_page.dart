import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../data/exercises.dart';
import '../scope.dart';
import '../strings.dart';

class TrainPage extends StatelessWidget {
  const TrainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final screening = state.screening!;
    if (!screening.canTrain) return const _ClearanceGate();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Entrenar', style: Theme.of(context).textTheme.headlineSmall),
        if (!screening.outcome.allowsVigorous)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mantén una intensidad moderada: deberías poder '
              'hablar mientras haces la serie.',
            ),
          ),
        const SizedBox(height: 8),
        for (final e in exerciseCatalog)
          Card(
            child: ListTile(
              key: Key('exercise-${e.id}'),
              title: Text(e.name),
              subtitle: Text(_subtitle(state.suggestionFor(e), e)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseLogPage(exercise: e),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _subtitle(ProgressionDecision? d, Exercise e) =>
      d == null ? 'Objetivo: ${e.targetReps} repeticiones' : Es.progression(d);
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

class ExerciseLogPage extends StatefulWidget {
  const ExerciseLogPage({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<ExerciseLogPage> createState() => _ExerciseLogPageState();
}

class _ExerciseLogPageState extends State<ExerciseLogPage> {
  final _load = TextEditingController();
  final _reps = TextEditingController();
  final List<LoggedSet> _sets = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_load.text.isEmpty) {
      final d = AppScope.of(context).suggestionFor(widget.exercise);
      if (d != null) _load.text = Es.kg(d.nextLoadKg).replaceAll(' kg', '');
    }
  }

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _addSet() {
    final load = double.tryParse(_load.text.replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text);
    if (load == null || load < 0 || load > 1000 || reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el peso y las repeticiones')),
      );
      return;
    }
    setState(() => _sets.add(LoggedSet(loadKg: load, reps: reps)));
    _reps.clear();
  }

  Future<void> _stop() async {
    final selected = await showDialog<Set<WarningSign>>(
      context: context,
      builder: (_) => const _WarningSignsDialog(),
    );
    if (selected == null || !mounted) return;
    if (evaluateSessionSafety(selected) ==
        SessionSafetyDecision.stopAndSeekCare) {
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
    final e = widget.exercise;
    final state = AppScope.of(context);
    final suggestion = state.suggestionFor(e);
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            suggestion == null
                ? 'Primera vez: elige un peso que puedas mover ${e.targetReps} '
                      'veces con buena técnica.'
                : Es.progression(suggestion),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
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
              Expanded(
                child: TextField(
                  key: const Key('set-reps'),
                  controller: _reps,
                  decoration: const InputDecoration(labelText: 'Repeticiones'),
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
          const SizedBox(height: 16),
          for (final (i, s) in _sets.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('${Es.kg(s.loadKg)} × ${s.reps}'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('session-save'),
            onPressed: _sets.isEmpty
                ? null
                : () async {
                    await state.logSession(e.id, List.of(_sets));
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: const Text('Terminar ejercicio'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('feel-bad'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.warning_amber),
            label: const Text('Me siento mal'),
            onPressed: _stop,
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
