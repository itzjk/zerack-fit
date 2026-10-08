import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zerack_core/zerack_core.dart';

import 'models.dart';
import 'store.dart';

/// Estado completo de la app. Se guarda como un único JSON versionado en el
/// almacenamiento local; nada sale del dispositivo desde aquí.
class AppState extends ChangeNotifier {
  AppState(this._store, {required this.foods, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'zerack.state.v1';
  static const exportFormat = 'zerack-fit-export';
  static const exportVersion = 1;

  final LocalStore _store;
  final DateTime Function() _clock;

  /// Base de alimentos del USDA embebida.
  final FoodIndex foods;

  bool _disclaimerAccepted = false;
  UserProfile? _profile;
  ScreeningRecord? _screening;
  Settings _settings = const Settings();
  final List<CheckIn> _checkIns = [];
  final List<FoodEntry> _food = [];
  final List<SessionRecord> _sessions = [];
  final List<WorkoutLog> _workouts = [];
  final List<ActivityLog> _activities = [];
  final List<WeightEntry> _weights = [];
  final List<PulseReading> _pulses = [];

  bool get disclaimerAccepted => _disclaimerAccepted;
  UserProfile? get profile => _profile;
  ScreeningRecord? get screening => _screening;
  Settings get settings => _settings;
  bool get onboarded =>
      _disclaimerAccepted && _profile != null && _screening != null;

  DateTime get now => _clock();
  String get today => dayKey(_clock());

  List<WorkoutLog> get workouts => List.unmodifiable(_workouts);
  List<ActivityLog> get activities => List.unmodifiable(_activities);
  List<WeightEntry> get weights => List.unmodifiable(_weights);
  List<PulseReading> get pulses => List.unmodifiable(_pulses);

  // ---------------------------------------------------------------- hoy

  CheckIn? get todayCheckIn {
    for (final c in _checkIns.reversed) {
      if (c.day == today) return c;
    }
    return null;
  }

  List<FoodEntry> foodOn(String day) =>
      List.unmodifiable(_food.where((f) => f.day == day));

  List<FoodEntry> get todayFood => foodOn(today);

  Nutrients get todayNutrients =>
      todayFood.fold(Nutrients.zero, (sum, f) => sum + f.nutrients);

  int get todayKcalEaten => todayNutrients.kcal.round();

  EnergyTarget? get energyTarget {
    final p = _profile;
    if (p == null) return null;
    return dailyEnergyTarget(
      totalKcal: p.totalKcal,
      restingKcal: p.restingKcal,
      goal: _settings.goal,
    );
  }

  ({double minG, double maxG})? get proteinRange {
    final p = _profile;
    return p == null ? null : dailyProteinRange(p.weightKg);
  }

  // ---------------------------------------------------------------- entreno

  TrainingPlan get plan => buildFullBodyPlan(
    level: _settings.level,
    daysPerWeek: _settings.daysPerWeek,
    gymAccess: _settings.gymAccess,
  );

  WorkoutTemplate get nextWorkout =>
      plan.next(_workouts.where((w) => w.templateId != null).length);

  /// Sesiones de un ejercicio, de la más vieja a la más nueva.
  List<SessionRecord> sessionsFor(String exerciseId) =>
      List.unmodifiable(_sessions.where((s) => s.exerciseId == exerciseId));

  /// Sugerencia de carga para la próxima sesión, o `null` si no hay historial
  /// o el ejercicio es con peso corporal.
  ProgressionDecision? suggestionFor(Exercise e, {int? targetReps}) {
    if (e.bodyweight) return null;
    final history = sessionsFor(e.id);
    if (history.isEmpty) return null;
    return decideProgression(
      history: [for (final s in history) s.asSession],
      config: ProgressionConfig(
        targetReps: targetReps ?? 12,
        smallestStepKg: e.smallestStepKg,
      ),
    );
  }

  WeeklySummary get weekSummary => summarizeWeek([
    for (final w in _workouts)
      ActivityBout(
        day: parseDayKey(w.day),
        minutes: w.minutes,
        intensity: ActivityIntensity.moderate,
        strength: true,
      ),
    for (final a in _activities)
      ActivityBout(
        day: parseDayKey(a.day),
        minutes: a.minutes,
        intensity: a.intensity,
      ),
  ], _clock());

  // ---------------------------------------------------------------- carga

  Future<void> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return;
    _apply(jsonDecode(raw) as Map<String, Object?>);
    notifyListeners();
  }

  void _apply(Map<String, Object?> j) {
    _disclaimerAccepted = j['disclaimerAccepted'] as bool? ?? false;
    final p = j['profile'];
    _profile = p == null
        ? null
        : UserProfile.fromJson(p as Map<String, Object?>);
    final s = j['screening'];
    _screening = s == null
        ? null
        : ScreeningRecord.fromJson(s as Map<String, Object?>);
    final st = j['settings'];
    _settings = st == null
        ? const Settings()
        : Settings.fromJson(st as Map<String, Object?>);
    _replace(_checkIns, j['checkIns'], CheckIn.fromJson);
    _replace(_food, j['food'], FoodEntry.fromJson);
    _replace(_sessions, j['sessions'], SessionRecord.fromJson);
    _replace(_workouts, j['workouts'], WorkoutLog.fromJson);
    _replace(_activities, j['activities'], ActivityLog.fromJson);
    _replace(_weights, j['weights'], WeightEntry.fromJson);
    _replace(_pulses, j['pulses'], PulseReading.fromJson);
  }

  static void _replace<T>(
    List<T> target,
    Object? raw,
    T Function(Map<String, Object?>) parse,
  ) {
    target
      ..clear()
      ..addAll(
        (raw as List<Object?>? ?? const []).cast<Map<String, Object?>>().map(
          parse,
        ),
      );
  }

  Map<String, Object?> _toJson() => {
    'disclaimerAccepted': _disclaimerAccepted,
    'profile': _profile?.toJson(),
    'screening': _screening?.toJson(),
    'settings': _settings.toJson(),
    'checkIns': [for (final c in _checkIns) c.toJson()],
    'food': [for (final f in _food) f.toJson()],
    'sessions': [for (final s in _sessions) s.toJson()],
    'workouts': [for (final w in _workouts) w.toJson()],
    'activities': [for (final a in _activities) a.toJson()],
    'weights': [for (final w in _weights) w.toJson()],
    'pulses': [for (final p in _pulses) p.toJson()],
  };

  Future<void> _save() async {
    notifyListeners();
    await _store.write(storageKey, jsonEncode(_toJson()));
  }

  // ---------------------------------------------------------------- export

  /// Copia completa de los datos, para que la persona se los lleve.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'format': exportFormat,
    'version': exportVersion,
    'exportedAt': _clock().toIso8601String(),
    'data': _toJson(),
  });

  /// Reemplaza todo con un respaldo. Valida antes de tocar nada.
  Future<void> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('El archivo no es JSON válido');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != exportFormat ||
        decoded['data'] is! Map<String, Object?>) {
      throw const FormatException('No es un respaldo de ZERACK Fit');
    }
    final data = decoded['data'] as Map<String, Object?>;
    // Parsea en un estado de prueba primero: si algo falla, no se pierde nada.
    AppState(MemoryStore(), foods: foods)._apply(data);
    _apply(data);
    await _save();
  }

  // ---------------------------------------------------------------- escritura

  Future<void> acceptDisclaimer() {
    _disclaimerAccepted = true;
    return _save();
  }

  Future<void> saveProfile(UserProfile p) {
    // Valida con el motor antes de guardar: lanza InvalidInput si no cuadra.
    p.restingKcal;
    final weightChanged = _profile?.weightKg != p.weightKg;
    _profile = p;
    if (weightChanged) _upsertWeight(p.weightKg);
    return _save();
  }

  Future<void> saveSettings(Settings s) {
    if (s.daysPerWeek < 2 || s.daysPerWeek > 3) {
      throw RangeError.range(s.daysPerWeek, 2, 3, 'daysPerWeek');
    }
    _settings = s;
    return _save();
  }

  Future<void> saveScreening(ScreeningAnswers answers) {
    _screening = ScreeningRecord(answers: answers, completedOn: today);
    // Quien ya entrena con regularidad empieza como intermedio (series
    // múltiples, ACSM 2009); quien no, como principiante.
    _settings = _settings.copyWith(
      level: answers.exercisesRegularly
          ? TrainingLevel.intermediate
          : TrainingLevel.novice,
    );
    return _save();
  }

  Future<void> confirmClearance(bool confirmed) {
    final s = _screening;
    if (s == null) return Future.value();
    _screening = s.withClearance(confirmed);
    return _save();
  }

  Future<void> saveCheckIn(HooperAnswers answers) {
    _checkIns
      ..removeWhere((c) => c.day == today)
      ..add(CheckIn(day: today, answers: answers));
    return _save();
  }

  Future<void> addFood(String label, int kcal) {
    if (kcal <= 0 || kcal > 10000) {
      throw RangeError.range(kcal, 1, 10000, 'kcal');
    }
    return addFoodEntry(
      FoodEntry(
        day: today,
        label: label.trim(),
        nutrients: Nutrients(
          kcal: kcal.toDouble(),
          proteinG: 0,
          fatG: 0,
          carbsG: 0,
        ),
      ),
    );
  }

  /// Agrega un alimento de la base con su porción en gramos.
  Future<void> addFoodFromDb(
    Food food,
    double grams, {
    FoodSource source = FoodSource.usda,
  }) {
    if (grams <= 0 || grams > 5000) {
      throw RangeError.range(grams.round(), 1, 5000, 'grams');
    }
    return addFoodEntry(
      FoodEntry(
        day: today,
        label: food.name,
        nutrients: food.forGrams(grams),
        source: source,
        foodId: food.id,
        grams: grams,
      ),
    );
  }

  Future<void> addFoodEntry(FoodEntry entry) {
    _food.add(entry);
    return _save();
  }

  Future<void> removeFood(FoodEntry entry) {
    _food.remove(entry);
    return _save();
  }

  Future<void> logSession(String exerciseId, List<LoggedSet> sets) {
    if (sets.isEmpty) throw ArgumentError.value(sets, 'sets', 'vacío');
    _sessions.add(
      SessionRecord(exerciseId: exerciseId, day: today, sets: sets),
    );
    return _save();
  }

  /// Guarda un entrenamiento completo con todas sus series.
  Future<void> logWorkout({
    required Map<String, List<LoggedSet>> setsByExercise,
    required int minutes,
    String? templateId,
  }) {
    final done = setsByExercise.entries.where((e) => e.value.isNotEmpty);
    if (done.isEmpty) {
      throw ArgumentError.value(setsByExercise, 'sets', 'sin series');
    }
    for (final e in done) {
      _sessions.add(
        SessionRecord(exerciseId: e.key, day: today, sets: e.value),
      );
    }
    _workouts.add(
      WorkoutLog(
        day: today,
        minutes: minutes.clamp(1, 600),
        templateId: templateId,
      ),
    );
    return _save();
  }

  Future<void> logActivity(
    String label,
    int minutes,
    ActivityIntensity intensity,
  ) {
    if (minutes <= 0 || minutes > 1440) {
      throw RangeError.range(minutes, 1, 1440, 'minutes');
    }
    _activities.add(
      ActivityLog(
        day: today,
        label: label.trim(),
        minutes: minutes,
        intensity: intensity,
      ),
    );
    return _save();
  }

  void _upsertWeight(double kg) {
    _weights
      ..removeWhere((w) => w.day == today)
      ..add(WeightEntry(day: today, kg: kg));
  }

  /// Registra el peso de hoy y actualiza el perfil.
  Future<void> logWeight(double kg) {
    final p = _profile;
    if (p == null) throw StateError('sin perfil');
    final updated = p.withWeight(kg);
    updated.restingKcal; // valida el rango
    _profile = updated;
    _upsertWeight(kg);
    return _save();
  }

  Future<void> logPulse(double bpm) {
    _pulses.add(PulseReading(at: _clock(), bpm: bpm));
    return _save();
  }

  /// Borra todo del dispositivo. Irreversible.
  Future<void> eraseAll() async {
    _disclaimerAccepted = false;
    _profile = null;
    _screening = null;
    _settings = const Settings();
    for (final l in <List<Object>>[
      _checkIns,
      _food,
      _sessions,
      _workouts,
      _activities,
      _weights,
      _pulses,
    ]) {
      l.clear();
    }
    await _store.delete(storageKey);
    notifyListeners();
  }
}
