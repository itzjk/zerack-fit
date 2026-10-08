import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_fit/src/ai/assistant.dart';
import 'package:zerack_fit/src/ai/claude_client.dart';
import 'package:zerack_fit/src/ai/food_scanner.dart';

import 'helpers.dart';

ClaudeClient _client(http.Client c, {String? baseUrl, String? key = 'sk'}) =>
    ClaudeClient(
      httpClient: c,
      config: ClaudeConfig(apiKey: key, baseUrl: baseUrl),
      sleep: (_) async {},
    );

void main() {
  group('ClaudeClient', () {
    test('API directa: modelo, cabeceras, caché y respaldo', () async {
      final api = ScriptedClaude([textResponse('hola')]);
      final res = await _client(api.client).create(
        system: 'S',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      );
      expect(res.text, 'hola');
      final body = api.requests.single;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['fallbacks'], 'default');
      expect(body.containsKey('thinking'), isFalse);
      expect((body['output_config'] as Map)['effort'], 'medium');
      final system = (body['system'] as List).single as Map;
      expect(system['cache_control'], {'type': 'ephemeral'});
      final h = api.headers.single;
      expect(h['x-api-key'], 'sk');
      expect(h['anthropic-version'], '2023-06-01');
      expect(h['anthropic-beta'], ClaudeClient.fallbackBeta);
    });

    test(
      'servidor intermedio: sin campo de respaldo ni clave obligatoria',
      () async {
        final api = ScriptedClaude([textResponse('ok')]);
        final c = _client(
          api.client,
          baseUrl: 'https://proxy.example',
          key: null,
        );
        expect(c.config.isUsable, isTrue);
        await c.create(system: 'S', messages: const []);
        expect(api.requests.single.containsKey('fallbacks'), isFalse);
        expect(api.headers.single.containsKey('anthropic-beta'), isFalse);
        expect(api.headers.single.containsKey('x-api-key'), isFalse);
      },
    );

    test('sin clave en API directa no hace la llamada', () async {
      var calls = 0;
      final c = _client(
        MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
        key: null,
      );
      await expectLater(
        c.create(system: 'S', messages: const []),
        throwsA(isA<ClaudeAuthError>()),
      );
      expect(calls, 0);
    });

    test('reintenta 529 y 429, luego responde', () async {
      var n = 0;
      final c = _client(
        MockClient((_) async {
          n++;
          if (n == 1) return http.Response('{"error":{"message":"x"}}', 529);
          if (n == 2) {
            return http.Response('{}', 429, headers: {'retry-after': '1'});
          }
          return http.Response(jsonEncode(textResponse('ya')), 200);
        }),
      );
      final r = await c.create(system: 'S', messages: const []);
      expect(r.text, 'ya');
      expect(n, 3);
    });

    test('errores tipados', () async {
      Future<void> expectError(int code, Matcher m) async {
        final c = _client(
          MockClient(
            (_) async => http.Response('{"error":{"message":"m"}}', code),
          ),
        );
        await expectLater(
          c.create(system: 'S', messages: const []),
          throwsA(m),
        );
      }

      await expectError(401, isA<ClaudeAuthError>());
      await expectError(400, isA<ClaudeBadRequest>());
      await expectError(500, isA<ClaudeUnavailable>());
      await expectError(429, isA<ClaudeRateLimited>());
    });

    test('refusal se convierte en excepción', () async {
      final c = _client(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'content': [], 'stop_reason': 'refusal'}),
            200,
          ),
        ),
      );
      await expectLater(
        c.create(system: 'S', messages: const []),
        throwsA(isA<ClaudeRefusal>()),
      );
    });

    test('red caída tras reintentos', () async {
      final c = _client(
        MockClient((req) async {
          throw http.ClientException('offline', req.url);
        }),
      );
      await expectLater(
        c.create(system: 'S', messages: const []),
        throwsA(isA<ClaudeNetworkError>()),
      );
    });

    test('describeClaudeError da texto en español', () {
      expect(
        describeClaudeError(const ClaudeAuthError('x')),
        contains('clave'),
      );
    });
  });

  group('FoodScanner', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

    test('mediaTypeOf por firma', () {
      expect(FoodScanner.mediaTypeOf(jpeg), 'image/jpeg');
      expect(
        FoodScanner.mediaTypeOf(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0]),
        ),
        'image/png',
      );
      expect(FoodScanner.mediaTypeOf(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });

    test(
      'envía imagen y formato estructurado; nutrientes salen del USDA',
      () async {
        final api = ScriptedClaude([
          textResponse(
            jsonEncode({
              'is_food': true,
              'items': [
                {
                  'food_id': 175036,
                  'name': 'tortillas',
                  'grams': 60,
                  'confidence': 'high',
                },
                {
                  'food_id': 999999,
                  'name': 'salsa rara',
                  'grams': 30,
                  'confidence': 'low',
                },
                {
                  'food_id': 173735,
                  'name': 'frijoles',
                  'grams': -5,
                  'confidence': 'medium',
                },
              ],
              'note': 'No veo si lleva aceite.',
            }),
          ),
        ]);
        final scanner = FoodScanner(_client(api.client), realFoods);
        final r = await scanner.scan(jpeg);

        final body = api.requests.single;
        final content =
            ((body['messages'] as List).single as Map)['content'] as List;
        final image = content.first as Map;
        expect(image['type'], 'image');
        expect((image['source'] as Map)['media_type'], 'image/jpeg');
        final format = (body['output_config'] as Map)['format'] as Map;
        expect(format['type'], 'json_schema');
        final system =
            ((body['system'] as List).single as Map)['text'] as String;
        expect(system, contains('175036|Tortilla de maíz'));

        expect(r.items, hasLength(2), reason: 'gramos negativos se descartan');
        final tortilla = r.items.first;
        expect(tortilla.food!.name, 'Tortilla de maíz');
        expect(tortilla.nutrients!.kcal, closeTo(218 * 0.6, 1e-9));
        expect(r.items[1].food, isNull, reason: 'id inexistente');
        expect(r.note, contains('aceite'));
      },
    );

    test('formato de imagen no soportado', () async {
      final scanner = FoodScanner(
        _client(MockClient((_) async => http.Response('', 200))),
        realFoods,
      );
      await expectLater(
        scanner.scan(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ClaudeBadRequest>()),
      );
    });

    test('respuesta no JSON', () {
      final scanner = FoodScanner(
        _client(MockClient((_) async => http.Response('', 200))),
        realFoods,
      );
      expect(() => scanner.parse('hola'), throwsA(isA<ClaudeBadRequest>()));
    });
  });

  group('Assistant', () {
    test('ciclo de herramientas, historial solo-agregar y propuesta', () async {
      final state = await onboardedState();
      final api = ScriptedClaude([
        toolResponse([
          ('t1', 'get_user_context', {}),
          ('t2', 'search_foods', {'query': 'huevo'}),
        ]),
        toolResponse([
          (
            't3',
            'propose_food_log',
            {
              'items': [
                {'food_id': 171287, 'grams': 100},
              ],
            },
          ),
        ]),
        textResponse('Te propuse 2 huevos.'),
      ]);
      final a = Assistant(_client(api.client), state);
      final turn = await a.send('Desayuné 2 huevos');

      expect(turn.text, 'Te propuse 2 huevos.');
      expect(turn.proposal!.items.single.food.id, 171287);
      expect(turn.proposal!.total.kcal, 143);
      expect(state.todayKcalEaten, 0, reason: 'la persona confirma en la app');

      expect(api.requests, hasLength(3));
      final second = api.requests[1]['messages'] as List;
      // user, assistant (tal cual), user con los dos tool_result juntos
      expect(second, hasLength(3));
      final echoed = (second[1] as Map)['content'] as List;
      expect(
        (echoed.first as Map)['signature'],
        'sig-t1',
        reason: 'los bloques de razonamiento se devuelven sin cambios',
      );
      final results = (second[2] as Map)['content'] as List;
      expect(results.map((r) => (r as Map)['tool_use_id']), ['t1', 't2']);
      final ctx =
          jsonDecode((results.first as Map)['content'] as String) as Map;
      expect((ctx['perfil'] as Map)['peso_kg'], 70);
      final foods =
          jsonDecode((results[1] as Map)['content'] as String) as List;
      expect(foods, isNotEmpty);

      // El tercer request contiene exactamente el segundo como prefijo.
      final third = api.requests[2]['messages'] as List;
      expect(jsonEncode(third.sublist(0, 3)), jsonEncode(second));

      final tools = api.requests.first['tools'] as List;
      expect(tools.every((t) => (t as Map)['strict'] == true), isTrue);
      expect(api.requests.first.containsKey('tool_choice'), isFalse);
    });

    test('herramienta con error regresa is_error', () async {
      final state = await onboardedState();
      final api = ScriptedClaude([
        toolResponse([
          (
            't1',
            'propose_food_log',
            {
              'items': [
                {'food_id': 1, 'grams': 50},
              ],
            },
          ),
        ]),
        textResponse('No encontré ese alimento.'),
      ]);
      final a = Assistant(_client(api.client), state);
      final turn = await a.send('agrega algo');
      expect(turn.proposal, isNull);
      final results =
          ((api.requests[1]['messages'] as List)[2] as Map)['content'] as List;
      expect((results.single as Map)['is_error'], isTrue);
    });

    test('mensaje vacío es un error', () async {
      final a = Assistant(
        _client(MockClient((_) async => http.Response('', 500))),
        await onboardedState(),
      );
      expect(() => a.send('  '), throwsArgumentError);
    });

    test('el prompt de sistema prohíbe diagnosticar y manda al 911', () {
      expect(Assistant.system, contains('No diagnosticas'));
      expect(Assistant.system, contains('911'));
    });
  });
}
