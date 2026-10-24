import 'package:flutter/material.dart';
import 'package:zerack_core/zerack_core.dart';

import '../scope.dart';
import '../strings.dart';
import '../theme/zerack_theme.dart';
import '../theme/zk_widgets.dart';
import 'exercise_guides.dart';
import 'exercise_motion.dart';
import 'workout_page.dart';

/// El ejercicio en movimiento, qué trabaja y cómo se hace.
class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({super.key, required this.exercise, this.planned});

  final Exercise exercise;

  /// Series y repeticiones si se abrió desde un día del plan.
  final PlannedExercise? planned;

  @override
  Widget build(BuildContext context) {
    final guide = exerciseGuides[exercise.id];
    final text = Theme.of(context).textTheme;
    final suggestion = AppScope.of(
      context,
    ).suggestionFor(exercise, targetReps: planned?.targetReps);
    final p = planned;
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('exercise-animation'),
            constraints: const BoxConstraints(maxHeight: 340),
            decoration: BoxDecoration(
              color: Zk.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Zk.hairlineStrong),
            ),
            padding: const EdgeInsets.all(12),
            child: Center(child: ExerciseAnimation(exerciseId: exercise.id)),
          ),
          const SizedBox(height: 16),
          Text(exercise.name, style: text.headlineSmall),
          if (guide != null) Text(guide.muscles, style: text.bodyMedium),
          if (p != null) ...[
            const SizedBox(height: 8),
            Text(
              '${p.sets} series × ${p.minReps}–${p.maxReps} '
              '${exercise.id == 'plank' ? 'segundos' : 'repeticiones'} · '
              'descanso ${p.rest.inMinutes > 0 ? '${p.rest.inMinutes} min' : '${p.rest.inSeconds} s'}',
              key: const Key('exercise-prescription'),
              style: text.titleSmall,
            ),
          ],
          if (!exercise.bodyweight && suggestion != null) ...[
            const SizedBox(height: 4),
            Text(Es.progression(suggestion)),
          ],
          if (guide != null) ...[
            const ZkSectionLabel('Cómo se hace'),
            for (final (i, step) in guide.steps.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Zk.cyanSoft,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Zk.cyan, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
          ],
          if (exercise.cue != null) ...[
            const SizedBox(height: 8),
            Text('Clave: ${exercise.cue!}', style: text.bodySmall),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('exercise-log'),
            icon: const Icon(Icons.edit_note),
            label: const Text('Registrar series'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WorkoutPage.single(exercise: exercise),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si sientes dolor (no solo esfuerzo), detente. Animación ilustrativa.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
