import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Lo que la app lee de Apple Health / Health Connect.
class HealthSnapshot {
  const HealthSnapshot({this.weightKg, this.stepsToday, this.restingHr});
  final double? weightKg;
  final int? stepsToday;
  final double? restingHr;
}

/// Puente a la salud del sistema. Interfaz para poder probar sin teléfono.
abstract interface class HealthBridge {
  bool get supported;
  Future<bool> requestAccess();
  Future<HealthSnapshot> read(DateTime now);
  Future<bool> writeWorkout(DateTime start, DateTime end, int kcal);
  Future<bool> writeWeight(double kg, DateTime at);
}

class PlatformHealthBridge implements HealthBridge {
  PlatformHealthBridge([Health? health]) : _health = health ?? Health();
  final Health _health;
  bool _configured = false;

  static const _read = [
    HealthDataType.WEIGHT,
    HealthDataType.STEPS,
    HealthDataType.RESTING_HEART_RATE,
  ];

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestAccess() async {
    if (!supported) return false;
    await _configure();
    if (defaultTargetPlatform == TargetPlatform.android &&
        !await _health.isHealthConnectAvailable()) {
      return false;
    }
    final android = defaultTargetPlatform == TargetPlatform.android;
    return _health.requestAuthorization(
      [
        ..._read,
        HealthDataType.WORKOUT,
        // En Health Connect las calorías del entreno son un registro aparte.
        if (android) HealthDataType.TOTAL_CALORIES_BURNED,
      ],
      permissions: [
        HealthDataAccess.READ_WRITE, // peso
        HealthDataAccess.READ, // pasos
        HealthDataAccess.READ, // pulso en reposo
        HealthDataAccess.WRITE, // entreno
        if (android) HealthDataAccess.WRITE,
      ],
    );
  }

  @override
  Future<HealthSnapshot> read(DateTime now) async {
    if (!supported) return const HealthSnapshot();
    await _configure();
    final midnight = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT, HealthDataType.RESTING_HEART_RATE],
      startTime: now.subtract(const Duration(days: 30)),
      endTime: now,
    );
    double? latest(HealthDataType t) {
      final of = points.where((p) => p.type == t).toList()
        ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final v = of.isEmpty ? null : of.last.value;
      return v is NumericHealthValue ? v.numericValue.toDouble() : null;
    }

    return HealthSnapshot(
      weightKg: latest(HealthDataType.WEIGHT),
      restingHr: latest(HealthDataType.RESTING_HEART_RATE),
      stepsToday: await _health.getTotalStepsInInterval(midnight, now),
    );
  }

  @override
  Future<bool> writeWorkout(DateTime start, DateTime end, int kcal) async {
    if (!supported) return false;
    await _configure();
    return _health.writeWorkoutData(
      activityType: defaultTargetPlatform == TargetPlatform.iOS
          ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
          : HealthWorkoutActivityType.STRENGTH_TRAINING,
      start: start,
      end: end,
      totalEnergyBurned: kcal,
      title: 'ZERACK Fit',
    );
  }

  @override
  Future<bool> writeWeight(double kg, DateTime at) async {
    if (!supported) return false;
    await _configure();
    return _health.writeHealthData(
      value: kg,
      type: HealthDataType.WEIGHT,
      startTime: at,
    );
  }
}

class FakeHealthBridge implements HealthBridge {
  FakeHealthBridge({this.snapshot = const HealthSnapshot()});
  HealthSnapshot snapshot;
  final writes = <String>[];

  @override
  bool get supported => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<HealthSnapshot> read(DateTime now) async => snapshot;

  @override
  Future<bool> writeWorkout(DateTime start, DateTime end, int kcal) async {
    writes.add('workout:$kcal');
    return true;
  }

  @override
  Future<bool> writeWeight(double kg, DateTime at) async {
    writes.add('weight:$kg');
    return true;
  }
}
