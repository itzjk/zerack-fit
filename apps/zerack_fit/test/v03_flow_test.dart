import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/ai/ai_service.dart';
import 'package:zerack_fit/src/ai/gemini_client.dart';
import 'package:zerack_fit/src/app.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/ui/assistant/assistant_page.dart';

import 'helpers.dart';

const _geminiKey = 'AIzaSyFAKEtestkeyForRepro1234567890abcd';

DateTime _monday() => DateTime(2026, 10, 19, 9);

Map<String, Object?> _text(String t) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': t},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
};

Map<String, Object?> _call(String name, Map<String, Object?> args) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {
            'functionCall': {'name': name, 'args': args},
          },
        ],
      },
      'finishReason': 'STOP',
    },
  ],
};

/// Un solo cliente HTTP que hace de Google, del servidor de ZERACK y de
/// Anthropic, y registra a quién se llamó.
class _Net {
  _Net(this.script);
  final List<Map<String, Object?>> script;
  final hosts = <String>[];
  final paths = <String>[];
  int _i = 0;

  late final MockClient client = MockClient((req) async {
    hosts.add(req.url.host);
    paths.add(req.url.path);
    if (req.method == 'GET') return http.Response('{"name":"ok"}', 200);
    if (req.url.path.endsWith('/v1/tts')) {
      return http.Response.bytes([9, 9, 9], 200);
    }
    if (_i >= script.length) return http.Response('{}', 500);
    return http.Response(jsonEncode(script[_i++]), 200);
  });
}

class _FakeAudio implements AudioOut {
  final played = <List<int>>[];
  @override
  Future<void> play(List<int> mp3) async => played.add(mp3);
  @override
  Future<void> stop() async {}
}

Future<AppState> _pump(
  WidgetTester t, {
  required AppState state,
  required AiService ai,
  AudioOut? audio,
}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  Widget app = ZerackApp(
    state: state,
    services: fakeServices(ai: ai),
    animatedBackdrop: false,
  );
  if (audio != null) app = AudioScope(out: audio, child: app);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
  return state;
}

void main() {
  testWidgets(
    'reproducción del fallo: una clave de Gemini se guarda, se verifica con '
    'Google y el agente habla con Gemini (antes iba a Anthropic)',
    (t) async {
      final net = _Net([_text('Te faltan 40 g de proteína.')]);
      final ai = AiService(
        secrets: MemorySecretStore(),
        httpClient: net.client,
      );
      final state = await onboardedState();
      await state.saveSettings(state.settings.copyWith(aiConsent: true));
      await _pump(t, state: state, ai: ai);

      await openTab(t, 'IA');
      await t.enterText(find.byKey(const Key('ai-key')), _geminiKey);
      await tapKey(t, 'ai-key-save');

      expect(await ai.geminiKey(), _geminiKey);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      expect(find.byKey(const Key('agent-provider')), findsOneWidget);
      expect(find.text('Gemini (tu clave)'), findsOneWidget);

      await t.enterText(find.byKey(const Key('chat-input')), 'hola');
      await tapKey(t, 'chat-send');
      expect(find.text('Te faltan 40 g de proteína.'), findsOneWidget);
      expect(net.hosts, isNot(contains('api.anthropic.com')));
      expect(net.hosts.toSet(), {'generativelanguage.googleapis.com'});
      expect(net.paths.last, contains(geminiModel));
    },
  );

  testWidgets('clave con formato desconocido: mensaje claro, no se guarda', (
    t,
  ) async {
    final ai = AiService(
      secrets: MemorySecretStore(),
      httpClient: _Net([]).client,
    );
    final state = await onboardedState();
    await state.saveSettings(state.settings.copyWith(aiConsent: true));
    await _pump(t, state: state, ai: ai);
    await openTab(t, 'IA');
    await t.enterText(find.byKey(const Key('ai-key')), 'mi-clave-123');
    await tapKey(t, 'ai-key-save');
    expect(find.byKey(const Key('ai-key-message')), findsOneWidget);
    expect(find.textContaining('No reconozco esta clave'), findsOneWidget);
    expect(await ai.route(state), isNull);
  });

  testWidgets(
    'servidor de ZERACK por defecto: sin clave, el agente propone un plan, '
    'se aplica y la respuesta se escucha con voz',
    (t) async {
      final net = _Net([
        _call('propose_plan_change', {
          'level': 'intermediate',
          'days_per_week': 4,
          'gym_access': true,
        }),
        _text('Te dejo el plan de 4 días para confirmar.'),
      ]);
      final ai = AiService(
        secrets: MemorySecretStore(),
        httpClient: net.client,
        buildServerUrl: 'https://api.zerack.example',
      );
      final audio = _FakeAudio();
      final state = await onboardedState(clock: _monday);
      await state.saveSettings(
        state.settings.copyWith(aiConsent: true, voiceReplies: true),
      );
      await _pump(t, state: state, ai: ai, audio: audio);

      await openTab(t, 'IA');
      expect(find.text('Servidor de ZERACK'), findsOneWidget);
      expect(find.byKey(const Key('voice-toggle')), findsOneWidget);
      await t.enterText(find.byKey(const Key('chat-input')), 'Quiero 4 días');
      await tapKey(t, 'chat-send');

      expect(find.textContaining('plan de 4 días'), findsOneWidget);
      expect(net.hosts.toSet(), {'api.zerack.example'});
      expect(net.paths.where((p) => p == '/v1/tts'), hasLength(1));
      expect(audio.played.single, [9, 9, 9]);

      expect(state.plan.daysPerWeek, 3, reason: 'aún no confirma');
      await tapKey(t, 'plan-accept');
      expect(state.plan.daysPerWeek, 4);
      expect(
        state.plan.forWeekday(2),
        isNotNull,
        reason: 'martes ahora entrena',
      );
      expect(find.byKey(const Key('plan-accept-done')), findsOneWidget);
    },
  );

  testWidgets('el agente explica una regla y muestra su fuente', (t) async {
    final net = _Net([
      _call('explain_rule', {'rule_id': 'proteina'}),
      _text('La recomendación viene de la ISSN.'),
    ]);
    final ai = AiService(secrets: MemorySecretStore(), httpClient: net.client);
    await ai.setApiKey(_geminiKey, verify: false);
    final state = await onboardedState();
    await state.saveSettings(state.settings.copyWith(aiConsent: true));
    await _pump(t, state: state, ai: ai);
    await openTab(t, 'IA');
    await t.enterText(
      find.byKey(const Key('chat-input')),
      '¿Por qué esa proteína?',
    );
    await tapKey(t, 'chat-send');
    expect(find.byKey(const Key('rule-proteina')), findsOneWidget);
    expect(find.textContaining('Jäger R'), findsOneWidget);
  });

  testWidgets('recuperación muscular: avisa si hoy toca un músculo sin 48 h', (
    t,
  ) async {
    // Domingo se hizo sentadilla; el lunes (cuerpo completo A) lleva piernas.
    var now = DateTime(2026, 10, 18, 19);
    final state = await onboardedState(clock: () => now);
    await state.logSession('back_squat', const [
      LoggedSet(loadKg: 60, reps: 10),
    ]);
    now = DateTime(2026, 10, 19, 9);
    await _pump(
      t,
      state: state,
      ai: AiService(secrets: MemorySecretStore(), httpClient: _Net([]).client),
    );
    await openTab(t, 'Entrenar');
    expect(find.byKey(const Key('recovery-card')), findsOneWidget);
    expect(find.textContaining('Piernas · descansando'), findsOneWidget);
    expect(find.byKey(const Key('recovery-warning')), findsOneWidget);
    expect(find.textContaining('Pecho · sin registro'), findsOneWidget);
  });

  testWidgets('Completa tu día agrega alimentos del USDA y cubre la proteína', (
    t,
  ) async {
    final state = await onboardedState();
    await _pump(
      t,
      state: state,
      ai: AiService(secrets: MemorySecretStore(), httpClient: _Net([]).client),
    );
    expect(find.byKey(const Key('complete-day')), findsOneWidget);
    expect(find.byKey(const Key('complete-day-remaining')), findsOneWidget);
    final before = state.todayNutrients.proteinG;
    await tapKey(t, 'complete-day-add');
    expect(state.todayFood, isNotEmpty);
    expect(state.todayNutrients.proteinG, greaterThan(before + 40));
    expect(
      state.todayNutrients.kcal,
      lessThanOrEqualTo(state.energyTarget!.kcal),
    );
    for (final f in state.todayFood) {
      expect(realFoods.byId(f.foodId!), isNotNull, reason: 'solo del USDA');
    }
  });
}
