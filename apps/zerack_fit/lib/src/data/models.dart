import 'package:zerack_core/zerack_core.dart';

/// Fecha local sin hora, en formato `AAAA-MM-DD`. Es la llave de los registros
/// diarios.
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

T _enumByName<T extends Enum>(List<T> values, Object? name) =>
    values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException('valor desconocido: $name'),
    );

class UserProfile {
  const UserProfile({
    required this.sex,
    required this.ageYears,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
  });

  final BiologicalSex sex;
  final int ageYears;
  final double weightKg;
  final double heightCm;
  final ActivityLevel activity;

  double get restingKcal => restingEnergyKcal(
    sex: sex,
    weightKg: weightKg,
    heightCm: heightCm,
    ageYears: ageYears,
  );

  double get totalKcal =>
      totalEnergyKcal(restingKcal: restingKcal, level: activity);

  Map<String, Object?> toJson() => {
    'sex': sex.name,
    'ageYears': ageYears,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'activity': activity.name,
  };

  factory UserProfile.fromJson(Map<String, Object?> j) => UserProfile(
    sex: _enumByName(BiologicalSex.values, j['sex']),
    ageYears: (j['ageYears'] as num).toInt(),
    weightKg: (j['weightKg'] as num).toDouble(),
    heightCm: (j['heightCm'] as num).toDouble(),
    activity: _enumByName(ActivityLevel.values, j['activity']),
  );
}

class ScreeningRecord {
  const ScreeningRecord({
    required this.answers,
    required this.completedOn,
    this.clearanceConfirmed = false,
  });

  final ScreeningAnswers answers;
  final String completedOn;

  /// La persona confirmó que tiene autorización médica para entrenar.
  final bool clearanceConfirmed;

  ScreeningOutcome get outcome => evaluateScreening(answers);

  bool get canTrain =>
      outcome.allowsTrainingWithoutClearance || clearanceConfirmed;

  ScreeningRecord withClearance(bool confirmed) => ScreeningRecord(
    answers: answers,
    completedOn: completedOn,
    clearanceConfirmed: confirmed,
  );

  Map<String, Object?> toJson() => {
    'exercisesRegularly': answers.exercisesRegularly,
    'disease': answers.hasKnownCardiometabolicRenalDisease,
    'signs': [for (final s in answers.signs) s.name],
    'completedOn': completedOn,
    'clearanceConfirmed': clearanceConfirmed,
  };

  factory ScreeningRecord.fromJson(Map<String, Object?> j) => ScreeningRecord(
    answers: ScreeningAnswers(
      exercisesRegularly: j['exercisesRegularly'] as bool,
      hasKnownCardiometabolicRenalDisease: j['disease'] as bool,
      signs: {
        for (final s in j['signs'] as List<Object?>)
          _enumByName(WarningSign.values, s),
      },
    ),
    completedOn: j['completedOn'] as String,
    clearanceConfirmed: j['clearanceConfirmed'] as bool? ?? false,
  );
}

class CheckIn {
  const CheckIn({required this.day, required this.answers});
  final String day;
  final HooperAnswers answers;

  int get score => readinessScore(answers);

  Map<String, Object?> toJson() => {
    'day': day,
    'sleep': answers.sleep,
    'stress': answers.stress,
    'fatigue': answers.fatigue,
    'soreness': answers.soreness,
  };

  factory CheckIn.fromJson(Map<String, Object?> j) => CheckIn(
    day: j['day'] as String,
    answers: HooperAnswers(
      sleep: (j['sleep'] as num).toInt(),
      stress: (j['stress'] as num).toInt(),
      fatigue: (j['fatigue'] as num).toInt(),
      soreness: (j['soreness'] as num).toInt(),
    ),
  );
}

/// Calorías consumidas que la persona anota a mano.
class FoodEntry {
  const FoodEntry({required this.day, required this.label, required this.kcal});
  final String day;
  final String label;
  final int kcal;

  Map<String, Object?> toJson() => {'day': day, 'label': label, 'kcal': kcal};

  factory FoodEntry.fromJson(Map<String, Object?> j) => FoodEntry(
    day: j['day'] as String,
    label: j['label'] as String,
    kcal: (j['kcal'] as num).toInt(),
  );
}

/// Sesión registrada de un ejercicio en un día.
class SessionRecord {
  const SessionRecord({
    required this.exerciseId,
    required this.day,
    required this.sets,
  });

  final String exerciseId;
  final String day;
  final List<LoggedSet> sets;

  ExerciseSession get asSession => ExerciseSession(sets);

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'day': day,
    'sets': [
      for (final s in sets) {'loadKg': s.loadKg, 'reps': s.reps},
    ],
  };

  factory SessionRecord.fromJson(Map<String, Object?> j) => SessionRecord(
    exerciseId: j['exerciseId'] as String,
    day: j['day'] as String,
    sets: [
      for (final s in (j['sets'] as List<Object?>).cast<Map<String, Object?>>())
        LoggedSet(
          loadKg: (s['loadKg'] as num).toDouble(),
          reps: (s['reps'] as num).toInt(),
        ),
    ],
  );
}
