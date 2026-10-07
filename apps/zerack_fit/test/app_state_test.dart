import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_core/zerack_core.dart';
import 'package:zerack_fit/src/data/app_state.dart';
import 'package:zerack_fit/src/data/exercises.dart';
import 'package:zerack_fit/src/data/models.dart';
import 'package:zerack_fit/src/data/store.dart';

const _profile = UserProfile(
  sex: BiologicalSex.female,
  ageYears: 30,
  weightKg: 62.5,
  heightCm: 165,
  activity: ActivityLevel.active,
);

void main() {
  late MemoryStore store;
  var now = DateTime(2026, 10, 7, 9);
  AppState make() => AppState(store, clock: () => now);

  setUp(() {
    store = MemoryStore();
    now = DateTime(2026, 10, 7, 9);
  });

  test('dayKey rellena con ceros', () {
    expect(dayKey(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
  });

  test('onboarded solo con aviso, perfil y screening', () async {
    final s = make();
    expect(s.onboarded, isFalse);
    await s.acceptDisclaimer();
    await s.saveProfile(_profile);
    expect(s.onboarded, isFalse);
    await s.saveScreening(
      const ScreeningAnswers(
        exercisesRegularly: false,
        hasKnownCardiometabolicRenalDisease: false,
        signs: {},
      ),
    );
    expect(s.onboarded, isTrue);
  });

  test('todo sobrevive a reiniciar la app', () async {
    final a = make();
    await a.acceptDisclaimer();
    await a.saveProfile(_profile);
    await a.saveScreening(
      const ScreeningAnswers(
        exercisesRegularly: false,
        hasKnownCardiometabolicRenalDisease: true,
        signs: {WarningSign.ankleEdema},
      ),
    );
    await a.confirmClearance(true);
    await a.saveCheckIn(
      HooperAnswers(sleep: 2, stress: 3, fatigue: 4, soreness: 5),
    );
    await a.addFood('Desayuno', 450);
    await a.logSession('back_squat', const [LoggedSet(loadKg: 60, reps: 10)]);

    final b = make();
    await b.load();
    expect(b.onboarded, isTrue);
    expect(b.profile!.weightKg, 62.5);
    expect(b.profile!.activity, ActivityLevel.active);
    expect(b.screening!.answers.signs, {WarningSign.ankleEdema});
    expect(b.screening!.clearanceConfirmed, isTrue);
    expect(b.screening!.canTrain, isTrue);
    expect(b.todayCheckIn!.answers.index, 14);
    expect(b.todayKcalEaten, 450);
    expect(b.sessionsFor('back_squat').single.sets.single.reps, 10);
  });

  test('sin autorización no puede entrenar si el screening lo pide', () async {
    final s = make();
    await s.saveScreening(
      const ScreeningAnswers(
        exercisesRegularly: false,
        hasKnownCardiometabolicRenalDisease: true,
        signs: {},
      ),
    );
    expect(s.screening!.canTrain, isFalse);
    await s.confirmClearance(true);
    expect(s.screening!.canTrain, isTrue);
  });

  test('comida y chequeo son por día', () async {
    final s = make();
    await s.addFood('Ayer', 900);
    await s.saveCheckIn(
      HooperAnswers(sleep: 1, stress: 1, fatigue: 1, soreness: 1),
    );
    now = DateTime(2026, 10, 8, 7);
    expect(s.todayKcalEaten, 0);
    expect(s.todayCheckIn, isNull);
  });

  test('repetir el chequeo del día lo reemplaza', () async {
    final s = make();
    await s.saveCheckIn(
      HooperAnswers(sleep: 7, stress: 7, fatigue: 7, soreness: 7),
    );
    await s.saveCheckIn(
      HooperAnswers(sleep: 1, stress: 1, fatigue: 1, soreness: 1),
    );
    expect(s.todayCheckIn!.score, 100);
  });

  test('rechaza calorías fuera de rango', () {
    final s = make();
    expect(() => s.addFood('x', 0), throwsRangeError);
    expect(() => s.addFood('x', 20000), throwsRangeError);
  });

  test('rechaza un perfil que el motor no acepta', () {
    final s = make();
    expect(
      () => s.saveProfile(
        const UserProfile(
          sex: BiologicalSex.male,
          ageYears: 12,
          weightKg: 40,
          heightCm: 150,
          activity: ActivityLevel.sedentary,
        ),
      ),
      throwsA(isA<InvalidInput>()),
    );
  });

  test('sugerencia de carga sale del historial', () async {
    final s = make();
    final squat = exerciseById('back_squat');
    expect(s.suggestionFor(squat), isNull);
    for (var i = 0; i < 2; i++) {
      await s.logSession('back_squat', const [
        LoggedSet(loadKg: 100, reps: 11),
        LoggedSet(loadKg: 100, reps: 11),
      ]);
    }
    final d = s.suggestionFor(squat)!;
    expect(d.action, ProgressionAction.increase);
    expect(d.nextLoadKg, 105);
  });

  test('borrar todo deja el almacenamiento vacío', () async {
    final s = make();
    await s.acceptDisclaimer();
    await s.addFood('x', 100);
    await s.eraseAll();
    expect(store.data, isEmpty);
    expect(s.disclaimerAccepted, isFalse);
    expect(s.todayKcalEaten, 0);
  });

  test('catálogo de ejercicios sin ids repetidos', () {
    final ids = exerciseCatalog.map((e) => e.id).toSet();
    expect(ids.length, exerciseCatalog.length);
  });
}
