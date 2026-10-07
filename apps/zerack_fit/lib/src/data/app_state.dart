import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zerack_core/zerack_core.dart';

import 'exercises.dart';
import 'models.dart';
import 'store.dart';

/// Estado completo de la app. Se guarda como un único JSON versionado en el
/// almacenamiento local.
class AppState extends ChangeNotifier {
  AppState(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'zerack.state.v1';

  final LocalStore _store;
  final DateTime Function() _clock;

  bool _disclaimerAccepted = false;
  UserProfile? _profile;
  ScreeningRecord? _screening;
  final List<CheckIn> _checkIns = [];
  final List<FoodEntry> _food = [];
  final List<SessionRecord> _sessions = [];

  bool get disclaimerAccepted => _disclaimerAccepted;
  UserProfile? get profile => _profile;
  ScreeningRecord? get screening => _screening;
  bool get onboarded =>
      _disclaimerAccepted && _profile != null && _screening != null;

  String get today => dayKey(_clock());

  CheckIn? get todayCheckIn {
    for (final c in _checkIns.reversed) {
      if (c.day == today) return c;
    }
    return null;
  }

  List<FoodEntry> get todayFood =>
      List.unmodifiable(_food.where((f) => f.day == today));

  int get todayKcalEaten => todayFood.fold(0, (sum, f) => sum + f.kcal);

  /// Sesiones de un ejercicio, de la más vieja a la más nueva.
  List<SessionRecord> sessionsFor(String exerciseId) =>
      List.unmodifiable(_sessions.where((s) => s.exerciseId == exerciseId));

  /// Sugerencia de carga para la próxima sesión, o `null` si no hay historial.
  ProgressionDecision? suggestionFor(Exercise e) {
    final history = sessionsFor(e.id);
    if (history.isEmpty) return null;
    return decideProgression(
      history: [for (final s in history) s.asSession],
      config: ProgressionConfig(
        targetReps: e.targetReps,
        smallestStepKg: e.smallestStepKg,
      ),
    );
  }

  Future<void> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, Object?>;
    _disclaimerAccepted = j['disclaimerAccepted'] as bool? ?? false;
    final p = j['profile'];
    _profile = p == null
        ? null
        : UserProfile.fromJson(p as Map<String, Object?>);
    final s = j['screening'];
    _screening = s == null
        ? null
        : ScreeningRecord.fromJson(s as Map<String, Object?>);
    _checkIns
      ..clear()
      ..addAll(_list(j['checkIns']).map(CheckIn.fromJson));
    _food
      ..clear()
      ..addAll(_list(j['food']).map(FoodEntry.fromJson));
    _sessions
      ..clear()
      ..addAll(_list(j['sessions']).map(SessionRecord.fromJson));
    notifyListeners();
  }

  static Iterable<Map<String, Object?>> _list(Object? v) =>
      (v as List<Object?>? ?? const []).cast<Map<String, Object?>>();

  Future<void> _save() async {
    notifyListeners();
    await _store.write(
      storageKey,
      jsonEncode({
        'disclaimerAccepted': _disclaimerAccepted,
        'profile': _profile?.toJson(),
        'screening': _screening?.toJson(),
        'checkIns': [for (final c in _checkIns) c.toJson()],
        'food': [for (final f in _food) f.toJson()],
        'sessions': [for (final s in _sessions) s.toJson()],
      }),
    );
  }

  Future<void> acceptDisclaimer() {
    _disclaimerAccepted = true;
    return _save();
  }

  Future<void> saveProfile(UserProfile p) {
    // Valida con el motor antes de guardar: lanza InvalidInput si no cuadra.
    p.restingKcal;
    _profile = p;
    return _save();
  }

  Future<void> saveScreening(ScreeningAnswers answers) {
    _screening = ScreeningRecord(answers: answers, completedOn: today);
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
    _food.add(FoodEntry(day: today, label: label.trim(), kcal: kcal));
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

  /// Borra todo del dispositivo. Irreversible.
  Future<void> eraseAll() async {
    _disclaimerAccepted = false;
    _profile = null;
    _screening = null;
    _checkIns.clear();
    _food.clear();
    _sessions.clear();
    await _store.delete(storageKey);
    notifyListeners();
  }
}
