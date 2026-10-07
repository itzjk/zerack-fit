import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

void main() {
  group('restingEnergyKcal (Mifflin-St Jeor)', () {
    test('hombre de 70 kg, 175 cm, 30 años', () {
      // 10·70 + 6.25·175 − 5·30 + 5
      expect(
        restingEnergyKcal(
          sex: BiologicalSex.male,
          weightKg: 70,
          heightCm: 175,
          ageYears: 30,
        ),
        closeTo(1648.75, 1e-9),
      );
    });

    test('mujer de 60 kg, 165 cm, 25 años', () {
      // 10·60 + 6.25·165 − 5·25 − 161
      expect(
        restingEnergyKcal(
          sex: BiologicalSex.female,
          weightKg: 60,
          heightCm: 165,
          ageYears: 25,
        ),
        closeTo(1345.25, 1e-9),
      );
    });

    test('rechaza menores de 18 y medidas imposibles', () {
      expect(
        () => restingEnergyKcal(
            sex: BiologicalSex.male, weightKg: 70, heightCm: 175, ageYears: 15),
        throwsA(isA<InvalidInput>()),
      );
      expect(
        () => restingEnergyKcal(
            sex: BiologicalSex.male, weightKg: 0, heightCm: 175, ageYears: 30),
        throwsA(isA<InvalidInput>()),
      );
      expect(
        () => restingEnergyKcal(
            sex: BiologicalSex.male,
            weightKg: double.nan,
            heightCm: 175,
            ageYears: 30),
        throwsA(isA<InvalidInput>()),
      );
    });
  });

  group('totalEnergyKcal (PAL FAO 2004)', () {
    test('multiplica por el PAL del nivel', () {
      expect(
        totalEnergyKcal(restingKcal: 1600, level: ActivityLevel.sedentary),
        closeTo(1600 * 1.53, 1e-9),
      );
    });

    test('los PAL caen dentro de los rangos del informe', () {
      expect(ActivityLevel.sedentary.pal, inInclusiveRange(1.40, 1.69));
      expect(ActivityLevel.active.pal, inInclusiveRange(1.70, 1.99));
      expect(ActivityLevel.vigorous.pal, inInclusiveRange(2.00, 2.40));
    });
  });

  group('activityKcal (Compendium 2024)', () {
    test('MET × kg × horas', () {
      expect(
        activityKcal(
          met: Compendium.resistanceMultiple.met,
          weightKg: 70,
          duration: const Duration(hours: 1),
        ),
        closeTo(245, 1e-9),
      );
    });

    test('neto resta el MET de reposo', () {
      expect(
        activityKcal(
          met: 3.5,
          weightKg: 70,
          duration: const Duration(minutes: 30),
          net: true,
        ),
        closeTo(87.5, 1e-9),
      );
    });

    test('catálogo sin códigos repetidos', () {
      final codes = Compendium.all.map((a) => a.code).toSet();
      expect(codes.length, Compendium.all.length);
    });
  });

  test('energyRange da ±10 %', () {
    final r = energyRange(2000);
    expect(r.low, closeTo(1800, 1e-9));
    expect(r.high, closeTo(2200, 1e-9));
  });
}
