import 'package:zerack_core/zerack_core.dart';

/// Fecha local sin hora, en formato `AAAA-MM-DD`. Es la llave de los registros
/// diarios.
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

T enumByName<T extends Enum>(List<T> values, Object? name, {T? fallback}) =>
    values.firstWhere(
      (v) => v.name == name,
      orElse: () =>
          fallback ?? (throw FormatException('valor desconocido: $name')),
    );

double _d(Object? v, [double fallback = 0]) =>
    (v as num?)?.toDouble() ?? fallback;

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

  UserProfile withWeight(double kg) => UserProfile(
    sex: sex,
    ageYears: ageYears,
    weightKg: kg,
    heightCm: heightCm,
    activity: activity,
  );

  Map<String, Object?> toJson() => {
    'sex': sex.name,
    'ageYears': ageYears,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'activity': activity.name,
  };

  factory UserProfile.fromJson(Map<String, Object?> j) => UserProfile(
    sex: enumByName(BiologicalSex.values, j['sex']),
    ageYears: (j['ageYears'] as num).toInt(),
    weightKg: _d(j['weightKg']),
    heightCm: _d(j['heightCm']),
    activity: enumByName(ActivityLevel.values, j['activity']),
  );
}

/// Preferencias de metas y entrenamiento.
class Settings {
  const Settings({
    this.goal = WeightGoal.maintain,
    this.level = TrainingLevel.novice,
    this.daysPerWeek = 3,
    this.gymAccess = true,
    this.aiConsent = false,
    this.aiBaseUrl,
    this.healthSync = false,
  });

  final WeightGoal goal;
  final TrainingLevel level;
  final int daysPerWeek;
  final bool gymAccess;

  /// La persona aceptó enviar a la IA los datos que cada función describe.
  final bool aiConsent;

  /// Servidor intermedio opcional compatible con la API de Anthropic. Si es
  /// `null` se usa la API directa con la clave de la persona.
  final String? aiBaseUrl;

  /// Sincronizar con Apple Health / Health Connect.
  final bool healthSync;

  Settings copyWith({
    WeightGoal? goal,
    TrainingLevel? level,
    int? daysPerWeek,
    bool? gymAccess,
    bool? aiConsent,
    String? Function()? aiBaseUrl,
    bool? healthSync,
  }) => Settings(
    goal: goal ?? this.goal,
    level: level ?? this.level,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    gymAccess: gymAccess ?? this.gymAccess,
    aiConsent: aiConsent ?? this.aiConsent,
    aiBaseUrl: aiBaseUrl == null ? this.aiBaseUrl : aiBaseUrl(),
    healthSync: healthSync ?? this.healthSync,
  );

  Map<String, Object?> toJson() => {
    'goal': goal.name,
    'level': level.name,
    'daysPerWeek': daysPerWeek,
    'gymAccess': gymAccess,
    'aiConsent': aiConsent,
    'aiBaseUrl': aiBaseUrl,
    'healthSync': healthSync,
  };

  factory Settings.fromJson(Map<String, Object?> j) => Settings(
    goal: enumByName(
      WeightGoal.values,
      j['goal'],
      fallback: WeightGoal.maintain,
    ),
    level: enumByName(
      TrainingLevel.values,
      j['level'],
      fallback: TrainingLevel.novice,
    ),
    daysPerWeek: (j['daysPerWeek'] as num?)?.toInt() ?? 3,
    gymAccess: j['gymAccess'] as bool? ?? true,
    aiConsent: j['aiConsent'] as bool? ?? false,
    aiBaseUrl: j['aiBaseUrl'] as String?,
    healthSync: j['healthSync'] as bool? ?? false,
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
          enumByName(WarningSign.values, s),
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

/// De dónde salieron los nutrientes de una comida.
enum FoodSource {
  /// La persona escribió las calorías.
  manual,

  /// Base USDA embebida.
  usda,

  /// Open Food Facts (datos de la comunidad, por código de barras).
  openFoodFacts,

  /// Foto analizada por la IA; los nutrientes vienen del USDA.
  scan,
}

class FoodEntry {
  const FoodEntry({
    required this.day,
    required this.label,
    required this.nutrients,
    this.source = FoodSource.manual,
    this.foodId,
    this.grams,
  });

  final String day;
  final String label;
  final Nutrients nutrients;
  final FoodSource source;
  final int? foodId;
  final double? grams;

  int get kcal => nutrients.kcal.round();

  Map<String, Object?> toJson() => {
    'day': day,
    'label': label,
    'kcal': nutrients.kcal,
    'protein': nutrients.proteinG,
    'fat': nutrients.fatG,
    'carbs': nutrients.carbsG,
    'source': source.name,
    'foodId': ?foodId,
    'grams': ?grams,
  };

  /// Acepta también el formato de la v0.1 (solo `label` y `kcal`).
  factory FoodEntry.fromJson(Map<String, Object?> j) => FoodEntry(
    day: j['day'] as String,
    label: j['label'] as String,
    nutrients: Nutrients(
      kcal: _d(j['kcal']),
      proteinG: _d(j['protein']),
      fatG: _d(j['fat']),
      carbsG: _d(j['carbs']),
    ),
    source: enumByName(
      FoodSource.values,
      j['source'],
      fallback: FoodSource.manual,
    ),
    foodId: (j['foodId'] as num?)?.toInt(),
    grams: (j['grams'] as num?)?.toDouble(),
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
        LoggedSet(loadKg: _d(s['loadKg']), reps: (s['reps'] as num).toInt()),
    ],
  );
}

/// Entrenamiento completo (una sesión A o B del plan, o libre).
class WorkoutLog {
  const WorkoutLog({required this.day, required this.minutes, this.templateId});

  final String day;
  final int minutes;

  /// `A`, `B` o `null` si fue un ejercicio suelto.
  final String? templateId;

  Map<String, Object?> toJson() => {
    'day': day,
    'minutes': minutes,
    'templateId': templateId,
  };

  factory WorkoutLog.fromJson(Map<String, Object?> j) => WorkoutLog(
    day: j['day'] as String,
    minutes: (j['minutes'] as num).toInt(),
    templateId: j['templateId'] as String?,
  );
}

/// Actividad aeróbica anotada a mano (caminar, bici...).
class ActivityLog {
  const ActivityLog({
    required this.day,
    required this.label,
    required this.minutes,
    required this.intensity,
  });

  final String day;
  final String label;
  final int minutes;
  final ActivityIntensity intensity;

  Map<String, Object?> toJson() => {
    'day': day,
    'label': label,
    'minutes': minutes,
    'intensity': intensity.name,
  };

  factory ActivityLog.fromJson(Map<String, Object?> j) => ActivityLog(
    day: j['day'] as String,
    label: j['label'] as String,
    minutes: (j['minutes'] as num).toInt(),
    intensity: enumByName(ActivityIntensity.values, j['intensity']),
  );
}

class WeightEntry {
  const WeightEntry({required this.day, required this.kg});
  final String day;
  final double kg;

  Map<String, Object?> toJson() => {'day': day, 'kg': kg};

  factory WeightEntry.fromJson(Map<String, Object?> j) =>
      WeightEntry(day: j['day'] as String, kg: _d(j['kg']));
}

class PulseReading {
  const PulseReading({required this.at, required this.bpm});
  final DateTime at;
  final double bpm;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'bpm': bpm};

  factory PulseReading.fromJson(Map<String, Object?> j) =>
      PulseReading(at: DateTime.parse(j['at'] as String), bpm: _d(j['bpm']));
}
