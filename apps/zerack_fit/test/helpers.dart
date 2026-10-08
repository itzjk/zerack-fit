import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/ai/ai_service.dart';
import 'package:zerack_fit/src/app.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/food_repository.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/data/off_client.dart';
import 'package:zerack_fit/src/data/store.dart';
import 'package:zerack_fit/src/health/health_service.dart';
import 'package:zerack_fit/src/services.dart';

/// La base real de alimentos que trae la app.
final FoodIndex realFoods = parseFoodIndex(
  File('assets/foods_es.json').readAsStringSync(),
);

AppState newState({DateTime Function()? clock, LocalStore? store}) =>
    AppState(store ?? MemoryStore(), foods: realFoods, clock: clock);

/// Responde a la API de Claude con las respuestas dadas, en orden.
class ScriptedClaude {
  ScriptedClaude(this.responses);
  final List<Map<String, Object?>> responses;
  final requests = <Map<String, Object?>>[];
  final headers = <Map<String, String>>[];

  late final MockClient client = MockClient((req) async {
    requests.add(jsonDecode(req.body) as Map<String, Object?>);
    headers.add(req.headers);
    if (requests.length > responses.length) {
      return http.Response('{"error":{"message":"sin guion"}}', 500);
    }
    return http.Response(
      jsonEncode(responses[requests.length - 1]),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Map<String, Object?> textResponse(String text) => {
  'content': [
    {'type': 'text', 'text': text},
  ],
  'stop_reason': 'end_turn',
};

Map<String, Object?> toolResponse(
  List<(String id, String name, Map<String, Object?> input)> uses,
) => {
  'content': [
    {'type': 'thinking', 'thinking': '', 'signature': 'sig-${uses.first.$1}'},
    for (final u in uses)
      {'type': 'tool_use', 'id': u.$1, 'name': u.$2, 'input': u.$3},
  ],
  'stop_reason': 'tool_use',
};

Services fakeServices({
  http.Client? claude,
  http.Client? off,
  HealthBridge? health,
  String? apiKey = 'sk-test',
}) {
  final secrets = MemorySecretStore();
  if (apiKey != null) secrets.data[AiService.apiKeyName] = apiKey;
  return Services(
    ai: AiService(
      secrets: secrets,
      httpClient: claude ?? MockClient((_) async => http.Response('', 500)),
    ),
    openFoodFacts: OpenFoodFactsClient(
      off ?? MockClient((_) async => http.Response('', 404)),
    ),
    health: health ?? FakeHealthBridge(),
  );
}

Future<AppState> onboardedState({
  bool exercises = true,
  bool disease = false,
  DateTime Function()? clock,
}) async {
  final s = newState(clock: clock);
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
  return s;
}

Future<AppState> pumpApp(
  WidgetTester t, {
  AppState? state,
  Services? services,
}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final s = state ?? newState();
  await t.pumpWidget(ZerackApp(state: s, services: services ?? fakeServices()));
  await t.pumpAndSettle();
  return s;
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> openTab(WidgetTester t, String label) async {
  await t.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await t.pumpAndSettle();
}
