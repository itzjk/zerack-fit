import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../scope.dart';
import 'workout_page.dart';

class WorkoutDraftCard extends StatefulWidget {
  const WorkoutDraftCard({super.key});

  @override
  State<WorkoutDraftCard> createState() => _WorkoutDraftCardState();
}

class _WorkoutDraftCardState extends State<WorkoutDraftCard> {
  bool _busy = false;

  Future<void> _discard() async {
    final state = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard unfinished workout?'),
        content: const Text(
          'Its saved sets will be removed. Completed workouts stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Keep workout'),
          ),
          FilledButton(
            key: const Key('workout-discard-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await state.discardWorkoutDraft();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout not discarded. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = AppScope.of(context).workoutDraft;
    if (draft == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unfinished workout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${draft.name} · ${draft.setCount} saved sets · ${dayKey(draft.startedAt)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('workout-resume'),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WorkoutPage.resume(),
                        ),
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume workout'),
              ),
              TextButton(
                key: const Key('workout-discard'),
                onPressed: _busy ? null : _discard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
