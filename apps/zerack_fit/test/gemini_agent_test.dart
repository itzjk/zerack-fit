import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/ai/ai_service.dart';
import 'package:zerack_fit/src/ai/assistant.dart';
import 'package:zerack_fit/src/ai/backends.dart';
import 'package:zerack_fit/src/ai/claude_client.dart';
import 'package:zerack_fit/src/ai/food_scanner.dart';
import 'package:zerack_fit/src/ai/gemini_client.dart';
import 'package:zerack_fit/src/ai/voice_service.dart';

import 'helpers.dart';

const _geminiKey = 'AIzaSyFAKEtestkeyForRepro1234567890abcd';

/// Respuestas de Gemini en orden; registra cada petición.
class ScriptedGemini {
  ScriptedGemini(this.responses);
  final List<Map<String, Object?>> responses;
  final requests = <http.Request>[];

  late final MockClient client = MockClient((req) async {
    requests.add(req);
    if (requests.length > responses.length) {
      return http.Response('{"error":{"message":"sin guion"}}', 500);
    }
    return http.Response(jsonEncode(responses[requests.length - 1]), 200);
  });

  Map<String, Object?> body(int i) =>
      jsonDecode(requests[i].body) as Map<String, Object?>;
}

Map<String, Object?> gText(String text) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
};

Map<String, Object?> gCall(
  List<(String, Map<String, Object?>)> calls, {
  String signature = 'sig-1',
}) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          for (final (i, c) in calls.indexed)
            {
              'functionCall': {'name': c.$1, 'args': c.$2},
              if (i == 0) 'thoughtSignature': signature,
            },
        ],
      },
      'finishReason': 'STOP',
    },
  ],
};

GeminiClient _direct(http.Client c) => GeminiClient(
  httpClient: c,
  access: const GeminiDirect(_geminiKey),
  sleep: (_) async {},
);

void main() {
  group('GeminiClient', () {
    test('directo: URL de Google y clave en cabecera, no en la URL', () async {
      final api = ScriptedGemini([gText('hola')]);
      final r = await _direct(api.client).generate({'contents': []});
      expect(r.text, 'hola');
      final req = api.requests.single;
      expect(
        req.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$geminiModel:generateContent',
      );
      expect(req.headers['x-goog-api-key'], _geminiKey);
      expect(req.url.queryParameters, isEmpty);
    });

    test(
      'por servidor: manda el id de dispositivo y nunca una clave',
      () async {
        final api = ScriptedGemini([gText('ok')]);
        final c = GeminiClient(
          httpClient: api.client,
          access: const GeminiViaServer(
            baseUrl: 'https://api.zerack.example',
            deviceId: 'dev-1',
          ),
        );
        await c.generate({'contents': []});
        final req = api.requests.single;
        expect(
          req.url.toString(),
          'https://api.zerack.example/v1/gemini/$geminiModel:generateContent',
        );
        expect(req.headers['x-device-id'], 'dev-1');
        expect(req.headers.containsKey('x-goog-api-key'), isFalse);
      },
    );

    test(
      'clave inválida (400 "API key not valid") es error de clave',
      () async {
        final c = _direct(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 400,
                  'message': 'API key not valid. Please pass a valid API key.',
                  'status': 'INVALID_ARGUMENT',
                },
              }),
              400,
            ),
          ),
        );
        await expectLater(
          c.generate({'contents': []}),
          throwsA(isA<ClaudeAuthError>()),
        );
      },
    );

    test('el límite diario del servidor no se reintenta', () async {
      var calls = 0;
      final c = GeminiClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'rate_limited', 'message': 'Límite de hoy'},
            }),
            429,
          );
        }),
        access: const GeminiViaServer(
          baseUrl: 'https://x.example',
          deviceId: 'd',
        ),
        sleep: (_) async {},
      );
      await expectLater(
        c.generate({'contents': []}),
        throwsA(isA<ClaudeRateLimited>()),
      );
      expect(calls, 1);
    });

    test('bloqueo por seguridad se trata como rechazo', () async {
      final c = _direct(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'promptFeedback': {'blockReason': 'SAFETY'},
            }),
            200,
          ),
        ),
      );
      await expectLater(
        c.generate({'contents': []}),
        throwsA(isA<ClaudeRefusal>()),
      );
    });
  });

  test('toGeminiSchema: tipos en mayúsculas, sin additionalProperties', () {
    final out = toGeminiSchema({
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'grams': {'type': 'number'},
            },
          },
        },
      },
    });
    expect(out['type'], 'OBJECT');
    expect(out.containsKey('additionalProperties'), isFalse);
    final items = (out['properties'] as Map)['items'] as Map;
    expect(items['type'], 'ARRAY');
    final inner = items['items'] as Map;
    expect(inner.containsKey('additionalProperties'), isFalse);
    expect(((inner['properties'] as Map)['grams'] as Map)['type'], 'NUMBER');
  });

  group('GeminiBackend', () {
    test(
      'escaneo: imagen en inlineData y respuesta JSON con esquema',
      () async {
        final api = ScriptedGemini([
          gText(
            jsonEncode({
              'is_food': true,
              'items': [
                {
                  'food_id': 175036,
                  'name': 'tortillas',
                  'grams': 60,
                  'confidence': 'high',
                },
              ],
              'note': '',
            }),
          ),
        ]);
        final scanner = FoodScanner(
          GeminiBackend(_direct(api.client)),
          realFoods,
        );
        final r = await scanner.scan(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]),
        );
        expect(r.items.single.food!.name, 'Tortilla de maíz');
        final body = api.body(0);
        final parts =
            ((body['contents'] as List).single as Map)['parts'] as List;
        expect((parts.first as Map)['inlineData'], isA<Map<String, Object?>>());
        expect(
          ((parts.first as Map)['inlineData'] as Map)['mimeType'],
          'image/jpeg',
        );
        final cfg = body['generationConfig'] as Map;
        expect(cfg['responseMimeType'], 'application/json');
        expect((cfg['responseSchema'] as Map)['type'], 'OBJECT');
      },
    );

    test('ciclo de funciones: devuelve el turno del modelo tal cual (firma) '
        'y las respuestas de función como objetos', () async {
      final state = await onboardedState();
      final api = ScriptedGemini([
        gCall([
          ('get_user_context', {}),
          ('search_foods', {'query': 'huevo'}),
        ]),
        gText('Listo.'),
      ]);
      final a = Assistant(GeminiBackend(_direct(api.client)), state);
      final turn = await a.send('¿Qué como?');
      expect(turn.text, 'Listo.');

      final second = api.body(1);
      final contents = second['contents'] as List;
      // user, modelo (tal cual), user con las dos respuestas
      expect(contents, hasLength(3));
      final modelTurn = contents[1] as Map;
      expect(modelTurn['role'], 'model');
      expect(
        ((modelTurn['parts'] as List).first as Map)['thoughtSignature'],
        'sig-1',
      );
      final responses = (contents[2] as Map)['parts'] as List;
      expect(responses, hasLength(2));
      final ctx = ((responses.first as Map)['functionResponse'] as Map);
      expect(ctx['name'], 'get_user_context');
      expect((ctx['response'] as Map)['perfil'], isA<Map<String, Object?>>());
      final search = ((responses[1] as Map)['functionResponse'] as Map);
      expect((search['response'] as Map)['result'], isA<List<Object?>>());

      // Herramientas declaradas sin additionalProperties; las sin
      // argumentos van sin parameters.
      final decls =
          ((second['tools'] as List).single as Map)['functionDeclarations']
              as List;
      final byName = {for (final d in decls) (d as Map)['name']: d};
      expect(byName['get_user_context']!.containsKey('parameters'), isFalse);
      expect(jsonEncode(decls), isNot(contains('additionalProperties')));
    });
  });

  group('acciones del agente', () {
    Future<(Assistant, ScriptedGemini)> agent(
      List<Map<String, Object?>> script, {
      bool disease = false,
    }) async {
      final state = await onboardedState(
        disease: disease,
        clock: () => DateTime(2026, 10, 19, 9),
      );
      final api = ScriptedGemini(script);
      return (Assistant(GeminiBackend(_direct(api.client)), state), api);
    }

    Map<String, Object?> lastResponse(ScriptedGemini api) {
      final contents = api.body(1)['contents'] as List;
      final parts = (contents.last as Map)['parts'] as List;
      return ((parts.single as Map)['functionResponse'] as Map)['response']
          as Map<String, Object?>;
    }

    test('propone cambiar el plan dentro del rango de ACSM', () async {
      final (a, api) = await agent([
        gCall([
          (
            'propose_plan_change',
            {'level': 'intermediate', 'days_per_week': 4, 'gym_access': true},
          ),
        ]),
        gText('Te dejo la tarjeta.'),
      ]);
      final t = await a.send('Quiero 4 días');
      final p = t.actions.single as PlanChangeProposal;
      expect((p.level, p.daysPerWeek), (TrainingLevel.intermediate, 4));
      expect(lastResponse(api)['pendiente_de_confirmar'], true);
    });

    test('rechaza días fuera del rango del nivel', () async {
      final (a, api) = await agent([
        gCall([
          (
            'propose_plan_change',
            {'level': 'novice', 'days_per_week': 6, 'gym_access': true},
          ),
        ]),
        gText('No se puede.'),
      ]);
      final t = await a.send('6 días');
      expect(t.actions, isEmpty);
      expect(lastResponse(api)['error'], contains('2–3'));
    });

    test(
      'no deja proponer avanzado si el screening limita a moderado',
      () async {
        final (a, api) = await agent([
          gCall([
            (
              'propose_plan_change',
              {'level': 'advanced', 'days_per_week': 5, 'gym_access': true},
            ),
          ]),
          gText('No.'),
        ], disease: true);
        final t = await a.send('avanzado');
        expect(t.actions, isEmpty);
        expect(lastResponse(api)['error'], contains('moderada'));
      },
    );

    test('start_workout: lunes abre la sesión; martes es descanso', () async {
      final (a, _) = await agent([
        gCall([
          ('start_workout', {'weekday': 1}),
        ]),
        gText('Vamos.'),
      ]);
      final t = await a.send('Empecemos');
      final s = t.actions.single as StartWorkoutAction;
      expect(s.weekday, 1);
      expect(s.workout.exercises, isNotEmpty);

      final (b, api) = await agent([
        gCall([
          ('start_workout', {'weekday': 7}),
        ]),
        gText('Hoy descansas.'),
      ]);
      expect((await b.send('domingo')).actions, isEmpty);
      expect(lastResponse(api)['error'], contains('descanso'));
    });

    test('explain_rule devuelve la regla con su fuente publicada', () async {
      final (a, api) = await agent([
        gCall([
          ('explain_rule', {'rule_id': 'deficit'}),
        ]),
        gText('Es por ACSM.'),
      ]);
      final t = await a.send('¿Por qué 500 kcal?');
      final c = t.actions.single as RuleCitation;
      expect(c.rule.source, Sources.acsmWeightLoss2001);
      expect(lastResponse(api)['fuente'], contains('Jakicic'));
    });

    test('completar el día propone alimentos del USDA', () async {
      final (a, api) = await agent([
        gCall([('suggest_foods_to_complete_day', {})]),
        gText('Mira la tarjeta.'),
      ]);
      final t = await a.send('Completa mi proteína');
      final p = t.actions.single as FoodProposal;
      expect(p.items, isNotEmpty);
      expect(p.reason, contains('proteína'));
      final r = lastResponse(api);
      expect(r['faltan_proteina_g'], greaterThan(0));
      expect(r['fuente'], contains('ISSN'));
    });

    test('recuperación muscular en el contexto del agente', () async {
      final (a, api) = await agent([
        gCall([('get_muscle_recovery', {})]),
        gText('ok'),
      ]);
      await a.send('¿Qué entreno?');
      final r = lastResponse(api);
      expect(r['regla'], contains('48 h'));
      expect(r['grupos'], hasLength(MuscleGroup.values.length));
    });

    test('el prompt sigue prohibiendo diagnosticar y manda al 911', () {
      expect(Assistant.system, contains('No diagnosticas'));
      expect(Assistant.system, contains('911'));
      expect(Assistant.system, contains('confirma'));
    });
  });

  group('AiService: proveedores y claves', () {
    AiService svc(http.Client c, {SecretStore? store, String server = ''}) =>
        AiService(
          secrets: store ?? MemorySecretStore(),
          httpClient: c,
          buildServerUrl: server,
        );

    test('una clave de Gemini se guarda como Gemini y se verifica con Google '
        '(antes se mandaba a Anthropic)', () async {
      final seen = <Uri>[];
      final ai = svc(
        MockClient((req) async {
          seen.add(req.url);
          expect(req.headers['x-goog-api-key'], _geminiKey);
          return http.Response('{"name":"models/$geminiModel"}', 200);
        }),
      );
      final r = await ai.setApiKey('  $_geminiKey  ');
      expect(r.provider, AiProvider.gemini);
      expect(r.check, KeyCheck.valid);
      expect(r.message, contains('Gemini guardada y verificada'));
      expect(await ai.geminiKey(), _geminiKey);
      expect(await ai.apiKey(), isNull, reason: 'no va al lugar de Anthropic');
      expect(seen.single.host, 'generativelanguage.googleapis.com');
      final state = await onboardedState();
      expect((await ai.route(state))!.provider, AiProvider.gemini);
    });

    test('si Google la rechaza, se dice claramente', () async {
      final ai = svc(MockClient((_) async => http.Response('{}', 400)));
      final r = await ai.setApiKey(_geminiKey);
      expect(r.check, KeyCheck.rejected);
      expect(r.message, contains('rechazó'));
    });

    test('sin internet: se guarda y avisa que no se comprobó', () async {
      final ai = svc(
        MockClient((req) async => throw http.ClientException('offline')),
      );
      final r = await ai.setApiKey('sk-ant-abc');
      expect(r.provider, AiProvider.anthropic);
      expect(r.check, KeyCheck.unverified);
      expect(await ai.apiKey(), 'sk-ant-abc');
    });

    test('formato desconocido no se guarda', () async {
      final store = MemorySecretStore();
      final ai = svc(
        MockClient((_) async => http.Response('', 200)),
        store: store,
      );
      await expectLater(
        ai.setApiKey('hola-mundo'),
        throwsA(isA<UnknownKeyFormat>()),
      );
      expect(store.data, isEmpty);
    });

    test('prioridad: tu Gemini > tu Anthropic > servidor de ZERACK', () async {
      final ai = svc(
        MockClient((_) async => http.Response('', 200)),
        server: 'https://api.zerack.example',
      );
      final state = await onboardedState();
      expect((await ai.route(state))!.provider, AiProvider.zerackServer);
      await ai.setApiKey('sk-ant-x', verify: false);
      expect((await ai.route(state))!.provider, AiProvider.anthropic);
      await ai.setApiKey(_geminiKey, verify: false);
      expect((await ai.route(state))!.provider, AiProvider.gemini);
      await ai.setApiKey(null);
      expect((await ai.route(state))!.provider, AiProvider.zerackServer);
    });

    test('con servidor no pide clave ni consentimiento extra', () async {
      final ai = svc(
        MockClient((_) async => http.Response('', 200)),
        server: 'https://api.zerack.example',
      );
      final state = await onboardedState();
      expect(await ai.unavailableReason(state), 'consent');
      await state.saveSettings(state.settings.copyWith(aiConsent: true));
      expect(await ai.unavailableReason(state), isNull);
      expect(await ai.voice(state), isNotNull);
    });

    test('id de dispositivo: UUID v4, se crea una vez', () async {
      final ai = svc(MockClient((_) async => http.Response('', 200)));
      final a = await ai.deviceId();
      expect(
        a,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(await ai.deviceId(), a);
    });

    test(
      'si el almacenamiento seguro falla, la clave cae al respaldo',
      () async {
        final fallback = MemorySecretStore();
        final store = FallbackSecretStore(_BrokenStore(), fallback);
        final ai = svc(
          MockClient((_) async => http.Response('', 200)),
          store: store,
        );
        await ai.setApiKey(_geminiKey, verify: false);
        expect(fallback.data[AiService.geminiKeyName], _geminiKey);
        expect(await ai.geminiKey(), _geminiKey);
      },
    );
  });

  group('VoiceService', () {
    test('speakable quita formato y recorta en una frase', () {
      expect(VoiceService.speakable('**Hola** _tú_ `x`'), 'Hola tú x');
      final long = '${'Frase corta. ' * 80}fin';
      final s = VoiceService.speakable(long);
      expect(s.length, lessThanOrEqualTo(VoiceService.maxChars));
      expect(s.endsWith('.'), isTrue);
    });

    test('pide mp3 al servidor con el id de dispositivo', () async {
      late http.Request seen;
      final v = VoiceService(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response.bytes([1, 2, 3], 200);
        }),
        serverUrl: 'https://api.zerack.example',
        deviceId: 'dev-9',
      );
      final mp3 = await v.synthesize('Hola **Itzael**');
      expect(mp3, [1, 2, 3]);
      expect(seen.url.toString(), 'https://api.zerack.example/v1/tts');
      expect(seen.headers['x-device-id'], 'dev-9');
      expect(jsonDecode(seen.body), {'text': 'Hola Itzael'});
    });

    test('límite de voz del día', () async {
      final v = VoiceService(
        httpClient: MockClient((_) async => http.Response('{}', 429)),
        serverUrl: 'https://x.example',
        deviceId: 'd',
      );
      await expectLater(
        v.synthesize('hola'),
        throwsA(isA<ClaudeRateLimited>()),
      );
    });
  });
}

class _BrokenStore implements SecretStore {
  @override
  Future<String?> read(String key) async => throw StateError('WebCrypto no');

  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('WebCrypto no');
}
