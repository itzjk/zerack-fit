import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/data/store.dart';

import 'helpers.dart';

void main() {
  var now = DateTime(2026, 10, 7, 9);
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 10, 7, 9));

  test('dayKey y parseDayKey son inversos', () {
    expect(dayKey(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
    expect(parseDayKey('2026-03-04'), DateTime(2026, 3, 4));
  });

  test('onboarded solo con aviso, perfil y screening', () async {
    final s = newState();
    expect(s.onboarded, isFalse);
    final o = await onboardedState();
    expect(o.onboarded, isTrue);
  });

  test('el screening fija el nivel inicial', () async {
    expect(
      (await onboardedState(exercises: false)).settings.level,
      TrainingLevel.novice,
    );
    expect(
      (await onboardedState(exercises: true)).settings.level,
      TrainingLevel.intermediate,
    );
  });

  test('todo sobrevive a reiniciar la app', () async {
    final store = MemoryStore();
    final a = newState(store: store, clock: clock);
    await a.acceptDisclaimer();
    await a.saveProfile(
      const UserProfile(
        sex: BiologicalSex.female,
        ageYears: 30,
        weightKg: 62.5,
        heightCm: 165,
        activity: ActivityLevel.active,
      ),
    );
    await a.saveScreening(
      const ScreeningAnswers(
        exercisesRegularly: false,
        hasKnownCardiometabolicRenalDisease: true,
        signs: {WarningSign.ankleEdema},
      ),
    );
    await a.confirmClearance(true);
    await a.saveSettings(a.settings.copyWith(goal: WeightGoal.lose));
    await a.saveCheckIn(
      HooperAnswers(sleep: 2, stress: 3, fatigue: 4, soreness: 5),
    );
    await a.addFoodFromDb(realFoods.byId(168878)!, 158);
    await a.logWorkout(
      setsByExercise: {
        'back_squat': const [LoggedSet(loadKg: 60, reps: 10)],
      },
      minutes: 45,
      templateId: 'A',
    );
    await a.logActivity('Caminar', 30, ActivityIntensity.moderate);
    await a.logPulse(64);

    final b = newState(store: store, clock: clock);
    await b.load();
    expect(b.onboarded, isTrue);
    expect(b.profile!.weightKg, 62.5);
    expect(b.screening!.canTrain, isTrue);
    expect(b.settings.goal, WeightGoal.lose);
    expect(b.todayCheckIn!.answers.index, 14);
    expect(b.todayKcalEaten, 205);
    expect(b.todayFood.single.source, FoodSource.usda);
    expect(b.workouts.single.templateId, 'A');
    expect(b.weekSummary.moderateEquivalentMinutes, 75);
    expect(b.pulses.single.bpm, 64);
    expect(b.weights.single.kg, 62.5, reason: 'el perfil registra el peso');
  });

  test('lee el formato de comida de la v0.1', () async {
    final store = MemoryStore()
      ..data[AppState.storageKey] = jsonEncode({
        'disclaimerAccepted': true,
        'food': [
          {'day': '2026-10-07', 'label': 'Tacos', 'kcal': 600},
        ],
      });
    final s = newState(store: store, clock: clock);
    await s.load();
    expect(s.todayKcalEaten, 600);
    expect(s.todayFood.single.source, FoodSource.manual);
  });

  test('alimento de la base: nutrientes del USDA por gramos', () async {
    final s = newState(clock: clock);
    final egg = realFoods.byId(171287)!;
    await s.addFoodFromDb(egg, 100);
    expect(s.todayNutrients.kcal, egg.per100g.kcal);
    expect(s.todayNutrients.proteinG, egg.per100g.proteinG);
    expect(() => s.addFoodFromDb(egg, 0), throwsRangeError);
  });

  test('meta de energía según la meta elegida', () async {
    final s = await onboardedState();
    final total = s.profile!.totalKcal;
    expect(s.energyTarget!.kcal, total);
    await s.saveSettings(s.settings.copyWith(goal: WeightGoal.lose));
    expect(s.energyTarget!.kcal, closeTo(total - 500, 1e-9));
    expect(s.proteinRange!.minG, closeTo(98, 1e-9));
  });

  test('rechaza días de entreno fuera de 2–3', () async {
    final s = newState();
    expect(
      () => s.saveSettings(s.settings.copyWith(daysPerWeek: 5)),
      throwsRangeError,
    );
  });

  test('el plan alterna A y B al terminar entrenos del plan', () async {
    final s = await onboardedState();
    expect(s.nextWorkout.id, 'A');
    await s.logWorkout(
      setsByExercise: {
        'back_squat': const [LoggedSet(loadKg: 60, reps: 10)],
      },
      minutes: 40,
      templateId: 'A',
    );
    expect(s.nextWorkout.id, 'B');
    await s.logWorkout(
      setsByExercise: {
        'dumbbell_curl': const [LoggedSet(loadKg: 10, reps: 10)],
      },
      minutes: 10,
    );
    expect(s.nextWorkout.id, 'B', reason: 'un ejercicio suelto no cuenta');
  });

  test('logWorkout sin series es un error', () {
    final s = newState();
    expect(
      () => s.logWorkout(setsByExercise: {'x': []}, minutes: 10),
      throwsArgumentError,
    );
  });

  test('logWeight actualiza el perfil y reemplaza el del mismo día', () async {
    final s = await onboardedState();
    await s.logWeight(71);
    await s.logWeight(70.5);
    expect(s.profile!.weightKg, 70.5);
    expect(s.weights.where((w) => w.day == s.today), hasLength(1));
    expect(() => s.logWeight(10), throwsA(isA<InvalidInput>()));
  });

  test('comida y chequeo son por día', () async {
    final s = newState(clock: clock);
    await s.addFood('Ayer', 900);
    await s.saveCheckIn(
      HooperAnswers(sleep: 1, stress: 1, fatigue: 1, soreness: 1),
    );
    now = DateTime(2026, 10, 8, 7);
    expect(s.todayKcalEaten, 0);
    expect(s.todayCheckIn, isNull);
    expect(s.foodOn('2026-10-07'), hasLength(1));
  });

  test('sugerencia de carga sale del historial; no en peso corporal', () async {
    final s = newState();
    final squat = exerciseById('back_squat');
    expect(s.suggestionFor(squat), isNull);
    for (var i = 0; i < 2; i++) {
      await s.logSession('back_squat', const [
        LoggedSet(loadKg: 100, reps: 13),
        LoggedSet(loadKg: 100, reps: 13),
      ]);
    }
    final d = s.suggestionFor(squat, targetReps: 12)!;
    expect(d.action, ProgressionAction.increase);
    expect(d.nextLoadKg, 105);
    expect(s.suggestionFor(exerciseById('pushup')), isNull);
  });

  group('exportar e importar', () {
    test('ida y vuelta conserva todo', () async {
      final a = await onboardedState(clock: clock);
      await a.addFoodFromDb(realFoods.byId(173944)!, 120);
      await a.logPulse(70);
      final json = a.exportJson();

      final b = newState(clock: clock);
      await b.importJson(json);
      expect(b.onboarded, isTrue);
      expect(b.todayKcalEaten, a.todayKcalEaten);
      expect(b.pulses.single.bpm, 70);
    });

    test('rechaza archivos que no son respaldo y no toca los datos', () async {
      final s = await onboardedState();
      await expectLater(s.importJson('no json'), throwsFormatException);
      await expectLater(s.importJson('{"a":1}'), throwsFormatException);
      await expectLater(
        s.importJson(
          jsonEncode({
            'format': AppState.exportFormat,
            'data': {
              'profile': {'sex': 'robot'},
            },
          }),
        ),
        throwsA(anything),
      );
      expect(s.onboarded, isTrue);
    });
  });

  test('borrar todo deja el almacenamiento vacío', () async {
    final store = MemoryStore();
    final s = newState(store: store);
    await s.acceptDisclaimer();
    await s.addFood('x', 100);
    await s.eraseAll();
    expect(store.data, isEmpty);
    expect(s.disclaimerAccepted, isFalse);
    expect(s.todayKcalEaten, 0);
  });
}
