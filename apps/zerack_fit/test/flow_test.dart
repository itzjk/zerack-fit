import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/ui/food/barcode_page.dart';
import 'package:zerack_fit/src/ui/food/scan_page.dart';
import 'package:zerack_fit/src/ui/train/workout_page.dart';

import 'helpers.dart';

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

void _push(WidgetTester t, Widget page) {
  t
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute<void>(builder: (_) => page));
}

void main() {
  testWidgets('onboarding completo hasta la pantalla Hoy', (t) async {
    final s = await pumpApp(t);

    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('disclaimer-continue')))
          .onPressed,
      isNull,
      reason: 'no se puede seguir sin aceptar el aviso',
    );
    await tapKey(t, 'disclaimer-check');
    await tapKey(t, 'disclaimer-continue');

    await tapKey(t, 'profile-save');
    expect(find.text('Elige tu sexo biológico'), findsOneWidget);
    await t.tap(find.text('Hombre'));
    await t.enterText(find.byKey(const Key('profile-age')), '30');
    await t.enterText(find.byKey(const Key('profile-weight')), '70');
    await t.enterText(find.byKey(const Key('profile-height')), '175');
    await tapKey(t, 'profile-save');
    expect(s.profile, isNotNull);

    await _yesNo(t, 'exercises', yes: false);
    await _yesNo(t, 'disease', yes: false);
    await tapKey(t, 'screening-submit');
    expect(find.text('Puedes empezar, poco a poco'), findsOneWidget);
    await tapKey(t, 'screening-save');

    expect(s.onboarded, isTrue);
    // 1648.75 × 1.53 = 2522.6
    expect(find.text('Mantener peso: meta de 2523 kcal'), findsOneWidget);
  });

  testWidgets('el perfil rechaza edades fuera de rango', (t) async {
    final s = newState();
    await s.acceptDisclaimer();
    await pumpApp(t, state: s);
    await t.tap(find.text('Mujer'));
    await t.enterText(find.byKey(const Key('profile-age')), '15');
    await t.enterText(find.byKey(const Key('profile-weight')), '60');
    await t.enterText(find.byKey(const Key('profile-height')), '160');
    await tapKey(t, 'profile-save');
    expect(find.text('Entre 18 y 100 años'), findsOneWidget);
    expect(s.profile, isNull);
  });

  testWidgets('enfermedad sin ejercicio regular bloquea Entrenar', (t) async {
    final s = await pumpApp(
      t,
      state: await onboardedState(exercises: false, disease: true),
    );
    await openTab(t, 'Entrenar');
    expect(find.text('Habla con tu médico antes de empezar'), findsOneWidget);
    expect(find.byKey(const Key('workout-start')), findsNothing);

    await tapKey(t, 'clearance-confirm');
    await tapKey(t, 'clearance-yes');
    expect(s.screening!.clearanceConfirmed, isTrue);
    expect(find.byKey(const Key('workout-start')), findsOneWidget);
  });

  testWidgets('buscar alimento del USDA y elegir porción', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await tapKey(t, 'food-search-open');
    await t.enterText(find.byKey(const Key('food-search')), 'arroz blanco');
    await t.pumpAndSettle();
    await tapKey(t, 'food-168878');
    await t.tap(find.textContaining('1 taza'));
    await t.pumpAndSettle();
    await tapKey(t, 'portion-add');
    expect(s.todayFood.single.grams, 158);
    expect(find.textContaining('Comiste 205 kcal'), findsOneWidget);
  });

  testWidgets('anotar a mano', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await tapKey(t, 'food-add');
    await t.enterText(find.byKey(const Key('food-label')), 'Tacos');
    await t.enterText(find.byKey(const Key('food-kcal')), '600');
    await t.pumpAndSettle();
    await tapKey(t, 'food-save');
    expect(s.todayKcalEaten, 600);
  });

  testWidgets('escanear plato: pide consentimiento, corrige y guarda', (
    t,
  ) async {
    final api = ScriptedClaude([
      textResponse(
        jsonEncode({
          'is_food': true,
          'items': [
            {
              'food_id': 175036,
              'name': 'tortillas',
              'grams': 50,
              'confidence': 'high',
            },
            {
              'food_id': null,
              'name': 'salsa misteriosa',
              'grams': 20,
              'confidence': 'low',
            },
          ],
          'note': '',
        }),
      ),
    ]);
    final s = await pumpApp(
      t,
      state: await onboardedState(),
      services: fakeServices(claude: api.client),
    );
    _push(
      t,
      ScanPage(picker: (_) async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 1])),
    );
    await t.pumpAndSettle();
    await tapKey(t, 'ai-consent');
    expect(s.settings.aiConsent, isTrue);

    await tapKey(t, 'scan-gallery');
    expect(find.text('Tortilla de maíz'), findsOneWidget);
    expect(
      find.textContaining('No está en la base: salsa misteriosa'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const Key('scan-grams-0')), '100');
    await t.pumpAndSettle();
    expect(find.textContaining('llevarías 218 de'), findsOneWidget);
    await tapKey(t, 'scan-save');

    final entry = s.todayFood.single;
    expect(entry.source, FoodSource.scan);
    expect(entry.kcal, 218, reason: 'kcal del USDA, no de la IA');
  });

  testWidgets('sin clave la IA pide una', (t) async {
    final s = await onboardedState();
    await s.saveSettings(s.settings.copyWith(aiConsent: true));
    final services = fakeServices(apiKey: null);
    await pumpApp(t, state: s, services: services);
    await openTab(t, 'IA');
    expect(find.byKey(const Key('ai-key')), findsOneWidget);
    await t.enterText(find.byKey(const Key('ai-key')), 'sk-nueva');
    await tapKey(t, 'ai-key-save');
    expect(await services.ai.apiKey(), 'sk-nueva');
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('asistente propone y la persona confirma', (t) async {
    final api = ScriptedClaude([
      toolResponse([
        (
          't1',
          'propose_food_log',
          {
            'items': [
              {'food_id': 171287, 'grams': 100},
            ],
          },
        ),
      ]),
      textResponse('Listo, revisa la propuesta.'),
    ]);
    final s = await onboardedState();
    await s.saveSettings(s.settings.copyWith(aiConsent: true));
    await pumpApp(
      t,
      state: s,
      services: fakeServices(claude: api.client),
    );
    await openTab(t, 'IA');
    await t.enterText(find.byKey(const Key('chat-input')), 'Comí 2 huevos');
    await tapKey(t, 'chat-send');
    expect(find.text('Listo, revisa la propuesta.'), findsOneWidget);
    expect(s.todayKcalEaten, 0);
    await tapKey(t, 'proposal-accept');
    expect(s.todayKcalEaten, 143);
    expect(find.text('✓ Agregado a tu día'), findsOneWidget);
  });

  testWidgets('código de barras manual con Open Food Facts', (t) async {
    final off = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Yogur bebible',
            'nutriments': {
              'energy-kcal_100g': 80,
              'proteins_100g': 3,
              'fat_100g': 2,
              'carbohydrates_100g': 12,
            },
          },
        }),
        200,
      ),
    );
    final s = await pumpApp(
      t,
      state: await onboardedState(),
      services: fakeServices(off: off),
    );
    _push(t, const BarcodePage(showCamera: false));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('barcode-manual')), '123');
    await tapKey(t, 'barcode-search');
    expect(find.byKey(const Key('barcode-message')), findsOneWidget);
    await t.enterText(find.byKey(const Key('barcode-manual')), '7501000123456');
    await tapKey(t, 'barcode-search');
    await t.enterText(find.byKey(const Key('portion-grams')), '250');
    await t.pumpAndSettle();
    await tapKey(t, 'portion-add');
    expect(s.todayFood.single.source, FoodSource.openFoodFacts);
    expect(s.todayKcalEaten, 200);
  });

  testWidgets('entrenamiento del plan: series, descanso y terminar', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await openTab(t, 'Entrenar');
    expect(find.text('Toca hoy: Cuerpo completo A'), findsOneWidget);
    await tapKey(t, 'workout-start');
    await t.enterText(find.byKey(const Key('set-load')), '60');
    await t.enterText(find.byKey(const Key('set-reps')), '10');
    await tapKey(t, 'set-add');
    expect(find.text('60 kg × 10'), findsOneWidget);
    expect(find.byKey(const Key('rest-timer')), findsOneWidget);
    await tapKey(t, 'session-finish');
    expect(s.workouts.single.templateId, 'A');
    expect(s.sessionsFor('back_squat'), hasLength(1));
    expect(find.text('Toca hoy: Cuerpo completo B'), findsOneWidget);
  });

  testWidgets('"Me siento mal" con un signo detiene la sesión', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await openTab(t, 'Entrenar');
    await tapKey(t, 'exercise-back_squat');
    await tapKey(t, 'feel-bad');
    await tapKey(t, 'feel-${WarningSign.dizzinessOrSyncope.name}');
    await tapKey(t, 'feel-submit');
    expect(find.byKey(const Key('stop-dialog')), findsOneWidget);
    await t.tap(find.text('Entendido'));
    await t.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsNothing, reason: 'cerró la sesión');
    expect(s.sessionsFor('back_squat'), isEmpty);
  });

  testWidgets('anotar actividad suma a la semana', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await openTab(t, 'Entrenar');
    await tapKey(t, 'activity-add');
    await t.enterText(find.byKey(const Key('activity-minutes')), '40');
    await t.pumpAndSettle();
    await tapKey(t, 'activity-save');
    expect(s.weekSummary.moderateEquivalentMinutes, 40);
  });

  testWidgets('cambiar la meta a bajar de peso cambia la meta del día', (
    t,
  ) async {
    await pumpApp(t, state: await onboardedState());
    await openTab(t, 'Perfil');
    final lose = find.descendant(
      of: find.byKey(const Key('goal-choice')),
      matching: find.text('Bajar de peso'),
    );
    await t.ensureVisible(lose);
    await t.tap(lose);
    await t.pumpAndSettle();
    await openTab(t, 'Hoy');
    expect(find.text('Bajar de peso: meta de 2023 kcal'), findsOneWidget);
  });

  testWidgets('registrar peso en Progreso', (t) async {
    final s = await pumpApp(t, state: await onboardedState());
    await openTab(t, 'Progreso');
    await tapKey(t, 'weight-add');
    await t.enterText(find.byKey(const Key('weight-input')), '69.5');
    await tapKey(t, 'weight-save');
    expect(s.profile!.weightKg, 69.5);
    expect(find.byKey(const Key('weight-last')), findsOneWidget);
  });

  testWidgets('chequeo diario muestra la nota', (t) async {
    await pumpApp(t, state: await onboardedState());
    await tapKey(t, 'checkin-open');
    await tapKey(t, 'checkin-save');
    expect(find.text('50'), findsOneWidget);
  });
}
