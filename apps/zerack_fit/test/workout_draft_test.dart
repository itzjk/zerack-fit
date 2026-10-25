import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/data/store.dart';
import 'package:zerack_fit/src/data/workout_draft.dart';

import 'helpers.dart';

class ControlledStore extends MemoryStore {
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> write(String key, String value) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('Disk unavailable');
    await super.write(key, value);
  }
}

WorkoutDraft draftAt(DateTime at, {int current = 0}) => WorkoutDraft(
  startedAt: at,
  name: 'Saved plan',
  templateId: 'A',
  planned: [
    for (final id in ['back_squat', 'bench_press'])
      PlannedExercise(
        exercise: exerciseById(id),
        sets: 3,
        minReps: 8,
        maxReps: 12,
        rest: const Duration(minutes: 2),
      ),
  ],
  current: current,
  restUntil: at.add(const Duration(minutes: 2)),
  sets: {
    'back_squat': const [LoggedSet(loadKg: 60, reps: 10)],
  },
);

void main() {
  final start = DateTime(2026, 10, 19, 9);

  test(
    'draft survives restart with plan, position, sets and rest deadline',
    () async {
      final store = MemoryStore();
      final state = newState(store: store);
      await state.saveWorkoutDraft(draftAt(start, current: 1));
      final restored = newState(store: store);
      await restored.load();
      final draft = restored.workoutDraft!;
      expect(draft.startedAt, start);
      expect(draft.name, 'Saved plan');
      expect(draft.templateId, 'A');
      expect(draft.current, 1);
      expect(draft.planned.last.exercise.id, 'bench_press');
      expect(draft.planned.first.sets, 3);
      expect(draft.planned.first.minReps, 8);
      expect(draft.planned.first.maxReps, 12);
      expect(draft.planned.first.rest, const Duration(minutes: 2));
      expect(draft.setCount, 1);
      expect(draft.sets['back_squat']!.single.loadKg, 60);
      expect(draft.sets['back_squat']!.single.reps, 10);
      expect(
        draft.restRemaining(start.add(const Duration(seconds: 45))),
        const Duration(seconds: 75),
      );
      expect(
        draft.restRemaining(start.add(const Duration(minutes: 3))),
        Duration.zero,
      );
      expect(restored.workouts, isEmpty);
      expect(restored.sessionsFor('back_squat'), isEmpty);
      expect(restored.weekSummary.strengthDays, 0);
    },
  );

  test(
    'finish atomically moves draft to history exactly once, on its start day',
    () async {
      final store = MemoryStore();
      final state = newState(
        store: store,
        clock: () => start.add(const Duration(days: 1)),
      );
      await state.saveWorkoutDraft(draftAt(start));
      expect(await state.finishWorkoutDraft(), isTrue);
      expect(await state.finishWorkoutDraft(), isFalse);
      expect(state.workouts, hasLength(1));
      expect(state.sessionsFor('back_squat'), hasLength(1));
      expect(state.workouts.single.day, dayKey(start));
      final restored = newState(store: store);
      await restored.load();
      expect(restored.workoutDraft, isNull);
      expect(restored.workouts, hasLength(1));
      expect(restored.sessionsFor('back_squat').single.sets.single.loadKg, 60);
    },
  );

  test('failed saves never announce success and remain retryable', () async {
    final store = ControlledStore()..fail = true;
    final state = newState(store: store);
    var notifications = 0;
    state.addListener(() => notifications++);
    await expectLater(state.saveWorkoutDraft(draftAt(start)), throwsStateError);
    expect(state.workoutDraft, isNull);
    expect(store.data, isEmpty);
    expect(notifications, 0);
    store.fail = false;
    await state.saveWorkoutDraft(draftAt(start));
    expect(state.workoutDraft!.setCount, 1);
    expect(notifications, 1);
  });

  test(
    'failed completion preserves draft and never duplicates history on retry',
    () async {
      final store = ControlledStore();
      final state = newState(
        store: store,
        clock: () => start.add(const Duration(minutes: 30)),
      );
      await state.saveWorkoutDraft(draftAt(start));
      store.fail = true;
      await expectLater(state.finishWorkoutDraft(), throwsStateError);
      expect(state.workoutDraft!.setCount, 1);
      expect(state.workouts, isEmpty);
      expect(state.sessionsFor('back_squat'), isEmpty);
      final restored = newState(store: store);
      await restored.load();
      expect(restored.workoutDraft!.setCount, 1);
      store.fail = false;
      await state.finishWorkoutDraft();
      expect(state.workouts.single.minutes, 30);
      expect(state.sessionsFor('back_squat'), hasLength(1));
    },
  );

  test(
    'overlapping completion is rejected while storage confirms the first',
    () async {
      final store = ControlledStore();
      final state = newState(store: store);
      await state.saveWorkoutDraft(draftAt(start));
      store.gate = Completer<void>();
      final pending = state.finishWorkoutDraft();
      await expectLater(state.finishWorkoutDraft(), throwsStateError);
      expect(state.workouts, isEmpty);
      store.gate!.complete();
      expect(await pending, isTrue);
      expect(state.workouts, hasLength(1));
    },
  );

  test('another session cannot silently replace the saved workout', () async {
    final state = newState();
    await state.saveWorkoutDraft(draftAt(start));
    await expectLater(
      state.saveWorkoutDraft(draftAt(start.add(const Duration(hours: 1)))),
      throwsStateError,
    );
    expect(state.workoutDraft!.startedAt, start);
  });

  test('discard removes only unfinished data and survives restart', () async {
    final store = MemoryStore();
    final state = newState(store: store);
    await state.logSession('bench_press', const [
      LoggedSet(loadKg: 40, reps: 8),
    ]);
    await state.saveWorkoutDraft(draftAt(start));
    await state.discardWorkoutDraft();
    final restored = newState(store: store);
    await restored.load();
    expect(restored.workoutDraft, isNull);
    expect(restored.sessionsFor('bench_press'), hasLength(1));
    expect(restored.sessionsFor('back_squat'), isEmpty);
  });

  test('failed discard keeps the saved workout', () async {
    final store = ControlledStore();
    final state = newState(store: store);
    await state.saveWorkoutDraft(draftAt(start));
    store.fail = true;
    await expectLater(state.discardWorkoutDraft(), throwsStateError);
    expect(state.workoutDraft!.setCount, 1);
  });

  test('old backups load without a draft and new backups include it', () async {
    final state = newState();
    await state.saveWorkoutDraft(draftAt(start));
    final restored = newState();
    await restored.importJson(state.exportJson());
    expect(restored.workoutDraft!.setCount, 1);
    final old = jsonDecode(state.exportJson()) as Map<String, dynamic>;
    (old['data'] as Map<String, dynamic>).remove('workoutDraft');
    await restored.importJson(jsonEncode(old));
    expect(restored.workoutDraft, isNull);
  });

  test('erase all clears the draft too', () async {
    final store = MemoryStore();
    final state = newState(store: store);
    await state.saveWorkoutDraft(draftAt(start));
    await state.eraseAll();
    expect(state.workoutDraft, isNull);
    final restored = newState(store: store);
    await restored.load();
    expect(restored.workoutDraft, isNull);
  });

  test('draft owns immutable copies of sets and rejects invalid data', () {
    final sets = <String, List<LoggedSet>>{
      'back_squat': [const LoggedSet(loadKg: 60, reps: 10)],
    };
    final draft = WorkoutDraft(
      startedAt: start,
      name: 'Squat',
      planned: [draftAt(start).planned.first],
      sets: sets,
    );
    sets['back_squat']!.clear();
    expect(draft.setCount, 1);
    expect(() => draft.sets['back_squat']!.clear(), throwsUnsupportedError);
    final invalid = draft.toJson()..['current'] = 20;
    expect(() => WorkoutDraft.fromJson(invalid), throwsFormatException);
    expect(
      () => WorkoutDraft(
        startedAt: start,
        name: 'Squat',
        planned: draft.planned,
        sets: {
          'back_squat': [const LoggedSet(loadKg: double.nan, reps: 10)],
        },
      ),
      throwsFormatException,
    );
  });
}
