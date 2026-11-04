// Capturas de pantalla de la app con datos de ejemplo.
//
//   flutter test test/screenshots_test.dart --update-goldens \
//     --dart-define=SCREENSHOTS=true
//
// Escribe PNG en docs/screenshots/. Sin SCREENSHOTS=true se omite (las
// capturas dependen de la plataforma y no sirven como prueba en el CI).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/ai/ai_service.dart';
import 'package:zerack_fit/src/app.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/ui/assistant/assistant_page.dart';

import 'helpers.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  await family('SpaceGrotesk', [
    'assets/fonts/SpaceGrotesk-Regular.ttf',
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-SemiBold.ttf',
  ]);
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

/// Martes 3 de noviembre de 2026, 18:00.
DateTime _now() => DateTime(2026, 11, 3, 18);

Future<AppState> _demoState() async {
  var now = DateTime(2026, 11, 1, 19);
  final s = newState(clock: () => now);
  await s.acceptDisclaimer();
  await s.saveProfile(
    const UserProfile(
      sex: BiologicalSex.male,
      ageYears: 30,
      weightKg: 78.4,
      heightCm: 175,
      activity: ActivityLevel.active,
    ),
  );
  await s.saveScreening(
    const ScreeningAnswers(
      exercisesRegularly: true,
      hasKnownCardiometabolicRenalDisease: false,
      signs: {},
    ),
  );
  await s.saveSettings(
    s.settings.copyWith(
      goal: WeightGoal.lose,
      level: TrainingLevel.intermediate,
      daysPerWeek: 4,
      aiConsent: true,
      voiceReplies: true,
    ),
  );
  // Domingo: piernas. Lunes: tren superior.
  await s.logWorkout(
    setsByExercise: {
      'back_squat': const [
        LoggedSet(loadKg: 80, reps: 10),
        LoggedSet(loadKg: 80, reps: 10),
        LoggedSet(loadKg: 80, reps: 9),
      ],
    },
    minutes: 45,
    templateId: 'lower',
  );
  now = DateTime(2026, 11, 2, 19);
  await s.logWorkout(
    setsByExercise: {
      'bench_press': const [
        LoggedSet(loadKg: 60, reps: 10),
        LoggedSet(loadKg: 60, reps: 10),
      ],
      'barbell_row': const [
        LoggedSet(loadKg: 50, reps: 10),
        LoggedSet(loadKg: 50, reps: 10),
      ],
    },
    minutes: 50,
    templateId: 'upper',
  );
  now = _now();
  await s.saveCheckIn(
    HooperAnswers(sleep: 2, stress: 3, fatigue: 3, soreness: 4),
  );
  await s.addFoodFromDb(realFoods.byId(171287)!, 150);
  await s.addFoodFromDb(realFoods.byId(175036)!, 96, source: FoodSource.scan);
  await s.addFoodFromDb(realFoods.byId(168878)!, 158);
  return s;
}

Map<String, Object?> _g(Map<String, Object?> part) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [part],
      },
      'finishReason': 'STOP',
    },
  ],
};

Future<void> _pumpPhone(WidgetTester t, Widget app) async {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../../docs/screenshots/v03-$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('capturas v0.3', (t) async {
    final net = MockClient((req) async {
      if (req.url.path.endsWith('/v1/tts')) return http.Response.bytes([], 200);
      return http.Response('{}', 500);
    });
    var step = 0;
    final script = [
      _g({
        'functionCall': {'name': 'suggest_foods_to_complete_day', 'args': {}},
      }),
      _g({
        'text':
            'Te faltan unos 81 g de proteína y aún te quedan calorías. Te dejo '
            'dos opciones del USDA para completarla hoy; confírmalas abajo.',
      }),
      _g({
        'functionCall': {
          'name': 'explain_rule',
          'args': {'rule_id': 'recuperacion'},
        },
      }),
      _g({
        'text':
            'Sí: tus piernas ya llevan 48 horas de descanso desde el domingo, '
            'así que hoy puedes hacer tren inferior. Pecho y espalda siguen '
            'descansando hasta mañana.',
      }),
    ];
    final agentNet = MockClient((req) async {
      if (req.url.path.endsWith('/v1/tts')) return http.Response.bytes([], 200);
      return http.Response(jsonEncode(script[step++ % script.length]), 200);
    });

    final state = await _demoState();
    final ai = AiService(
      secrets: MemorySecretStore(),
      httpClient: agentNet,
      buildServerUrl: 'https://api.zerack.example',
    );
    await _pumpPhone(
      t,
      AudioScope(
        out: _SilentAudio(),
        child: ZerackApp(
          state: state,
          services: fakeServices(ai: ai, off: net),
          animatedBackdrop: false,
        ),
      ),
    );
    await _shot(t, '1-hoy');

    await t.scrollUntilVisible(
      find.byKey(const Key('complete-day')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _shot(t, '2-completa-tu-dia');

    await openTab(t, 'Entrenar');
    await _shot(t, '3-recuperacion');

    await openTab(t, 'IA');
    await t.enterText(
      find.byKey(const Key('chat-input')),
      'Completa mi proteína de hoy',
    );
    await tapKey(t, 'chat-send');
    await t.enterText(
      find.byKey(const Key('chat-input')),
      '¿Puedo entrenar piernas hoy?',
    );
    await tapKey(t, 'chat-send');
    await _shot(t, '4-agente');

    await openTab(t, 'Perfil');
    await t.scrollUntilVisible(
      find.byKey(const Key('ai-route')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.byKey(const Key('ai-switch')));
    await t.pumpAndSettle();
    await _shot(t, '5-perfil-ia');
  }, skip: !_enabled);
}

class _SilentAudio implements AudioOut {
  @override
  Future<void> play(List<int> mp3) async {}
  @override
  Future<void> stop() async {}
}
