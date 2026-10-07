import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/app.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/data/store.dart';

Future<AppState> _pump(WidgetTester t, {AppState? state}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final s = state ?? AppState(MemoryStore());
  await t.pumpWidget(ZerackApp(state: s));
  return s;
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _yesNo(WidgetTester t, String prefix, {required bool yes}) async {
  final f = find.descendant(
    of: find.byKey(Key('$prefix-choice')),
    matching: find.text(yes ? 'Sí' : 'No'),
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<AppState> _onboarded(
  WidgetTester t, {
  required bool exercises,
  required bool disease,
}) async {
  final s = AppState(MemoryStore());
  await s.acceptDisclaimer();
  await s.saveProfile(
    const UserProfile(
      sex: BiologicalSex.male,
      ageYears: 30,
      weightKg: 70,
      heightCm: 175,
      activity: ActivityLevel.sedentary,
    ),
  );
  await s.saveScreening(
    ScreeningAnswers(
      exercisesRegularly: exercises,
      hasKnownCardiometabolicRenalDisease: disease,
      signs: const {},
    ),
  );
  return _pump(t, state: s);
}

void main() {
  testWidgets('onboarding completo hasta la pantalla Hoy', (t) async {
    final s = await _pump(t);

    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('disclaimer-continue')))
          .onPressed,
      isNull,
      reason: 'no se puede seguir sin aceptar el aviso',
    );
    await _tap(t, 'disclaimer-check');
    await _tap(t, 'disclaimer-continue');

    await _tap(t, 'profile-save');
    expect(find.text('Elige tu sexo biológico'), findsOneWidget);
    await t.tap(find.text('Hombre'));
    await t.enterText(find.byKey(const Key('profile-age')), '30');
    await t.enterText(find.byKey(const Key('profile-weight')), '70');
    await t.enterText(find.byKey(const Key('profile-height')), '175');
    await _tap(t, 'profile-save');
    expect(s.profile, isNotNull);

    await _yesNo(t, 'exercises', yes: false);
    await _yesNo(t, 'disease', yes: false);
    await _tap(t, 'screening-submit');
    expect(find.text('Puedes empezar, poco a poco'), findsOneWidget);
    await _tap(t, 'screening-save');

    expect(s.onboarded, isTrue);
    // 1648.75 × 1.53 = 2522.6 → ±10 %: 2270–2775
    expect(find.text('Gastas aprox. 2270–2775 kcal'), findsOneWidget);
  });

  testWidgets('el perfil rechaza edades fuera de rango', (t) async {
    final s = AppState(MemoryStore());
    await s.acceptDisclaimer();
    await _pump(t, state: s);
    await t.tap(find.text('Mujer'));
    await t.enterText(find.byKey(const Key('profile-age')), '15');
    await t.enterText(find.byKey(const Key('profile-weight')), '60');
    await t.enterText(find.byKey(const Key('profile-height')), '160');
    await _tap(t, 'profile-save');
    expect(find.text('Entre 18 y 100 años'), findsOneWidget);
    expect(s.profile, isNull);
  });

  testWidgets('enfermedad sin ejercicio regular bloquea Entrenar', (t) async {
    final s = await _onboarded(t, exercises: false, disease: true);
    await t.tap(find.text('Entrenar'));
    await t.pumpAndSettle();
    expect(find.text('Habla con tu médico antes de empezar'), findsOneWidget);
    expect(find.byKey(const Key('exercise-back_squat')), findsNothing);

    await _tap(t, 'clearance-confirm');
    await _tap(t, 'clearance-yes');
    expect(s.screening!.clearanceConfirmed, isTrue);
    expect(find.byKey(const Key('exercise-back_squat')), findsOneWidget);
  });

  testWidgets('registrar series y anotar comida', (t) async {
    final s = await _onboarded(t, exercises: true, disease: false);

    await _tap(t, 'food-add');
    await t.enterText(find.byKey(const Key('food-label')), 'Tacos');
    await t.enterText(find.byKey(const Key('food-kcal')), '600');
    await t.pumpAndSettle();
    await _tap(t, 'food-save');
    expect(find.text('Comiste 600 kcal'), findsOneWidget);

    await t.tap(find.text('Entrenar'));
    await t.pumpAndSettle();
    await _tap(t, 'exercise-bench_press');
    await t.enterText(find.byKey(const Key('set-load')), '60');
    await t.enterText(find.byKey(const Key('set-reps')), '10');
    await _tap(t, 'set-add');
    expect(find.text('60 kg × 10'), findsOneWidget);
    await _tap(t, 'session-save');
    expect(s.sessionsFor('bench_press'), hasLength(1));
  });

  testWidgets('"Me siento mal" con un signo detiene la sesión', (t) async {
    final s = await _onboarded(t, exercises: true, disease: false);
    await t.tap(find.text('Entrenar'));
    await t.pumpAndSettle();
    await _tap(t, 'exercise-back_squat');
    await _tap(t, 'feel-bad');
    await _tap(t, 'feel-${WarningSign.dizzinessOrSyncope.name}');
    await _tap(t, 'feel-submit');
    expect(find.byKey(const Key('stop-dialog')), findsOneWidget);
    await t.tap(find.text('Entendido'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('exercise-back_squat')),
      findsOneWidget,
      reason: 'regresa a la lista sin guardar',
    );
    expect(s.sessionsFor('back_squat'), isEmpty);
  });

  testWidgets('chequeo diario muestra la nota', (t) async {
    await _onboarded(t, exercises: true, disease: false);
    await _tap(t, 'checkin-open');
    await _tap(t, 'checkin-save');
    // Todo en 4 (normal) → índice 16 → 50.
    expect(find.text('50'), findsOneWidget);
  });
}
