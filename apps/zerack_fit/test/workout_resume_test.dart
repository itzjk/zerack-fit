import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_fit/src/ui/train/workout_page.dart';

import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/app.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/store.dart';

import 'helpers.dart';
import 'workout_draft_test.dart' show ControlledStore, draftAt;

Future<AppState> persistedState(
  LocalStore store,
  DateTime Function() clock,
) async {
  final state = newState(store: store, clock: clock);
  await state.importJson((await onboardedState(clock: clock)).exportJson());
  return state;
}

Future<void> leaveWorkout(WidgetTester t) async {
  Navigator.of(t.element(find.byType(WorkoutPage))).pop();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('leaving a workout preserves every logged set', (t) async {
    final state = await onboardedState(clock: () => DateTime(2026, 10, 19, 9));
    await pumpApp(t, state: state);
    await openTab(t, 'Entrenar');
    await tapKey(t, 'workout-start');
    await t.enterText(find.byKey(const Key('set-load')), '60');
    await t.enterText(find.byKey(const Key('set-reps')), '10');
    await tapKey(t, 'set-add');
    expect(find.text('60 kg × 10'), findsOneWidget);
    await leaveWorkout(t);
    await tapKey(t, 'workout-start');
    expect(find.text('60 kg × 10'), findsOneWidget);
    expect(state.workouts, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'restart resumes the original plan, exercise, load and real rest deadline',
    (t) async {
      var now = DateTime(2026, 10, 19, 9);
      final store = MemoryStore();
      final state = await persistedState(store, () => now);
      await state.saveWorkoutDraft(draftAt(now, current: 1));
      await pumpApp(t, state: state);
      await t.pumpWidget(const SizedBox.shrink());
      now = now.add(const Duration(seconds: 45));
      final restored = newState(store: store, clock: () => now);
      await restored.load();
      await restored.saveSettings(
        restored.settings.copyWith(
          level: TrainingLevel.advanced,
          daysPerWeek: 6,
        ),
      );
      await pumpApp(t, state: restored);
      await openTab(t, 'Entrenar');
      await tapKey(t, 'workout-resume');
      expect(find.text('Saved plan'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      final chips = t.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips[1].selected, isTrue);
      expect(find.text('Descanso: 1:15'), findsOneWidget);
      now = now.add(const Duration(minutes: 2));
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('rest-timer')), findsNothing);
      await t.enterText(find.byKey(const Key('set-load')), '40');
      await t.enterText(find.byKey(const Key('set-reps')), '8');
      await tapKey(t, 'set-add');
      await leaveWorkout(t);
      await tapKey(t, 'workout-resume');
      expect(find.text('40 kg × 8'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byKey(const Key('set-load'))).controller!.text,
        '40',
      );
      await tapKey(t, 'session-save');
      expect(restored.workouts, hasLength(1));
      expect(restored.workouts.single.templateId, 'A');
      expect(restored.sessionsFor('back_squat').single.sets.single.reps, 10);
      expect(restored.sessionsFor('bench_press').single.sets.single.reps, 8);
      expect(restored.workoutDraft, isNull);
      expect(find.byKey(const Key('workout-resume')), findsNothing);
    },
  );

  testWidgets('skipping rest persists and a draft is available on a rest day', (
    t,
  ) async {
    var now = DateTime(2026, 10, 19, 9);
    final store = MemoryStore();
    final state = await persistedState(store, () => now);
    await state.saveWorkoutDraft(draftAt(now));
    await state.saveSettings(
      state.settings.copyWith(level: TrainingLevel.novice),
    );
    now = DateTime(2026, 10, 20, 9);
    await pumpApp(t, state: state);
    await openTab(t, 'Entrenar');
    expect(find.byKey(const Key('day-rest')), findsOneWidget);
    await tapKey(t, 'workout-resume');
    expect(find.byKey(const Key('rest-timer')), findsNothing);
    await t.enterText(find.byKey(const Key('set-reps')), '9');
    await tapKey(t, 'set-add');
    expect(find.byKey(const Key('rest-timer')), findsOneWidget);
    await t.tap(find.text('Saltar'));
    await t.pumpAndSettle();
    await leaveWorkout(t);
    final restored = newState(store: store, clock: () => now);
    await restored.load();
    expect(restored.workoutDraft!.restUntil, isNull);
    await tapKey(t, 'workout-resume');
    expect(find.byKey(const Key('rest-timer')), findsNothing);
    expect(find.text('60 kg × 9'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('storage failure keeps input and no fake saved set appears', (
    t,
  ) async {
    final store = ControlledStore();
    final state = await persistedState(store, () => DateTime(2026, 10, 19, 9));
    await pumpApp(t, state: state);
    await openTab(t, 'Entrenar');
    await tapKey(t, 'workout-start');
    await t.enterText(find.byKey(const Key('set-load')), '60');
    await t.enterText(find.byKey(const Key('set-reps')), '10');
    store.fail = true;
    await tapKey(t, 'set-add');
    expect(find.text('Set not saved. Please try again.'), findsOneWidget);
    expect(find.text('60 kg × 10'), findsNothing);
    expect(
      t.widget<TextField>(find.byKey(const Key('set-reps'))).controller!.text,
      '10',
    );
    expect(state.workoutDraft, isNull);
    store.fail = false;
    await tapKey(t, 'set-add');
    expect(find.text('60 kg × 10'), findsOneWidget);
    store.fail = true;
    await tapKey(t, 'session-save');
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(state.workouts, isEmpty);
    expect(state.workoutDraft!.setCount, 1);
    store.fail = false;
    await tapKey(t, 'session-save');
    expect(state.workouts, hasLength(1));
  });

  testWidgets(
    'discard requires confirmation and cancel preserves the session',
    (t) async {
      if (Platform.environment['FIT_CAPTURE_DIR'] != null) {
        await t.runAsync(() async {
          final textFont = FontLoader('SpaceGrotesk')
            ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Medium.ttf'))
            ..addFont(
              rootBundle.load('assets/fonts/SpaceGrotesk-SemiBold.ttf'),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await Future.wait([textFont.load(), icons.load()]);
        });
      }
      final state = await onboardedState();
      await state.saveWorkoutDraft(draftAt(state.now));
      await pumpApp(t, state: state);
      await openTab(t, 'Entrenar');
      await tapKey(t, 'workout-discard');
      await t.tap(find.text('Keep workout'));
      await t.pumpAndSettle();
      expect(state.workoutDraft!.setCount, 1);
      await tapKey(t, 'workout-discard');
      await tapKey(t, 'workout-discard-confirm');
      expect(state.workoutDraft, isNull);
      expect(state.workouts, isEmpty);
      expect(find.byKey(const Key('workout-resume')), findsNothing);
    },
  );

  testWidgets('safety stop never offers to resume the stopped workout', (
    t,
  ) async {
    final state = await onboardedState();
    await state.saveWorkoutDraft(draftAt(state.now));
    await pumpApp(t, state: state);
    await openTab(t, 'Entrenar');
    await tapKey(t, 'workout-resume');
    await tapKey(t, 'feel-bad');
    await tapKey(t, 'feel-${WarningSign.dizzinessOrSyncope.name}');
    await tapKey(t, 'feel-submit');
    await t.tap(find.text('Entendido'));
    await t.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsNothing);
    expect(state.workoutDraft, isNull);
    expect(state.workouts, isEmpty);
  });

  testWidgets('empty sessions create no draft and invalid sets are not saved', (
    t,
  ) async {
    final state = await onboardedState(clock: () => DateTime(2026, 10, 19, 9));
    await pumpApp(t, state: state);
    await openTab(t, 'Entrenar');
    await tapKey(t, 'workout-start');
    await tapKey(t, 'set-add');
    expect(state.workoutDraft, isNull);
    expect(
      t.widget<TextButton>(find.byKey(const Key('session-save'))).onPressed,
      isNull,
    );
    await leaveWorkout(t);
    expect(find.byKey(const Key('workout-resume')), findsNothing);
  });

  for (final width in [375.0, 900.0, 1280.0]) {
    testWidgets('resume and logging fit a $width wide viewport', (t) async {
      if (Platform.environment['FIT_CAPTURE_DIR'] != null) {
        await t.runAsync(() async {
          final textFont = FontLoader('SpaceGrotesk')
            ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Medium.ttf'))
            ..addFont(
              rootBundle.load('assets/fonts/SpaceGrotesk-SemiBold.ttf'),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await Future.wait([textFont.load(), icons.load()]);
        });
      }
      final state = await onboardedState();
      await state.saveWorkoutDraft(draftAt(state.now));
      await pumpApp(t, state: state);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(width, 1000);
      final app = t.widget<ZerackApp>(find.byType(ZerackApp));
      await t.pumpWidget(
        RepaintBoundary(key: const Key('capture-root'), child: app),
      );
      await t.pumpAndSettle();
      await openTab(t, 'Entrenar');
      expect(t.takeException(), isNull);
      await tapKey(t, 'workout-resume');
      expect(find.text('60 kg × 10'), findsOneWidget);
      expect(t.takeException(), isNull);
      final input = t.getRect(find.byKey(const Key('set-reps')));
      final add = t.getRect(find.byKey(const Key('set-add')));
      expect(input.left, greaterThanOrEqualTo(0));
      expect(add.right, lessThanOrEqualTo(width));
      final capture = Platform.environment['FIT_CAPTURE_DIR'];
      if (capture != null && width == 375) {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture-root')),
        );
        await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$capture/workout-375.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
