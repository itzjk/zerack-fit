import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_fit/src/ai/ai_service.dart';
import 'package:zerack_fit/src/data/off_client.dart';
import 'package:zerack_fit/src/ui/pulse/red_channel.dart';

import 'helpers.dart';

void main() {
  group('Open Food Facts', () {
    const body = {
      'status': 1,
      'product': {
        'product_name': 'Galletas X',
        'serving_quantity': 30,
        'nutriments': {
          'energy-kcal_100g': 480,
          'proteins_100g': 6.5,
          'fat_100g': '20',
          'carbohydrates_100g': 68,
        },
      },
    };

    test('parsea nutrientes por 100 g y porción', () {
      final f = OpenFoodFactsClient.parse('7501000123456', jsonEncode(body))!;
      expect(f.name, 'Galletas X');
      expect(f.per100g.kcal, 480);
      expect(f.per100g.fatG, 20);
      expect(f.portions.single.grams, 30);
      expect(f.id, isNegative);
    });

    test('sin calorías o sin producto: null', () {
      expect(OpenFoodFactsClient.parse('12345678', '{"status":0}'), isNull);
      expect(
        OpenFoodFactsClient.parse(
          '12345678',
          jsonEncode({
            'status': 1,
            'product': {'nutriments': {}},
          }),
        ),
        isNull,
      );
    });

    test('solo envía el código y un User-Agent', () async {
      late Uri seen;
      late Map<String, String> headers;
      final c = OpenFoodFactsClient(
        MockClient((req) async {
          seen = req.url;
          headers = req.headers;
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await c.lookup('7501000123456');
      expect(seen.path, '/api/v2/product/7501000123456');
      expect(headers['User-Agent'], OpenFoodFactsClient.userAgent);
    });

    test('valida el código', () {
      expect(OpenFoodFactsClient.isValidBarcode('123'), isFalse);
      expect(OpenFoodFactsClient.isValidBarcode('7501000123456'), isTrue);
      expect(
        () => OpenFoodFactsClient(
          MockClient((_) async => http.Response('', 200)),
        ).lookup('abc'),
        throwsArgumentError,
      );
    });
  });

  group('AiService', () {
    test('requiere consentimiento y luego clave', () async {
      final state = await onboardedState();
      final ai = AiService(
        secrets: MemorySecretStore(),
        httpClient: MockClient((_) async => http.Response('', 500)),
      );
      expect(await ai.unavailableReason(state), 'consent');
      await state.saveSettings(state.settings.copyWith(aiConsent: true));
      expect(await ai.unavailableReason(state), 'key');
      await ai.setApiKey('  sk-x  ');
      expect(await ai.apiKey(), 'sk-x');
      expect(await ai.unavailableReason(state), isNull);
      await ai.setApiKey('');
      expect(await ai.apiKey(), isNull);
    });

    test('con servidor intermedio no pide clave', () async {
      final state = await onboardedState();
      await state.saveSettings(
        state.settings.copyWith(
          aiConsent: true,
          aiBaseUrl: () => 'https://proxy.example',
        ),
      );
      final ai = AiService(
        secrets: MemorySecretStore(),
        httpClient: MockClient((_) async => http.Response('', 500)),
      );
      expect(await ai.unavailableReason(state), isNull);
    });
  });

  group('meanRed', () {
    test('BGRA toma el canal rojo', () {
      // 2×2 píxeles BGRA con rojo = 200.
      final bytes = Uint8List.fromList([
        for (var i = 0; i < 4; i++) ...[10, 20, 200, 255],
      ]);
      expect(
        meanRed(
          format: FrameFormat.bgra8888,
          planes: [FramePlane(bytes, 8)],
          width: 2,
          height: 2,
          step: 1,
        ),
        200,
      );
    });

    test('YUV: rojo ≈ Y + 1.402·(V − 128)', () {
      final y = Uint8List.fromList(List.filled(16, 100));
      final u = Uint8List.fromList(List.filled(4, 128));
      final v = Uint8List.fromList(List.filled(4, 178));
      final r = meanRed(
        format: FrameFormat.yuv420,
        planes: [FramePlane(y, 4), FramePlane(u, 2, 1), FramePlane(v, 2, 1)],
        width: 4,
        height: 4,
        step: 1,
      );
      expect(r, closeTo(100 + 1.402 * 50, 1e-9));
    });
  });

  group('base de alimentos embebida', () {
    test('168 alimentos con ids únicos y nutrientes válidos', () {
      final all = realFoods.all;
      expect(all.length, 168);
      expect(all.map((f) => f.id).toSet().length, all.length);
      for (final f in all) {
        expect(f.per100g.kcal, inInclusiveRange(0, 900), reason: f.name);
        expect(f.per100g.proteinG, greaterThanOrEqualTo(0), reason: f.name);
        for (final p in f.portions) {
          expect(p.grams, greaterThan(0), reason: '${f.name} ${p.label}');
        }
      }
    });

    test('búsquedas comunes en español encuentran algo', () {
      for (final q in [
        'tortilla',
        'frijoles',
        'pollo',
        'platano',
        'aguacate',
        'huevo',
        'arroz',
        'nopal',
        'queso',
        'atun',
      ]) {
        expect(realFoods.search(q), isNotEmpty, reason: q);
      }
    });
  });
}
