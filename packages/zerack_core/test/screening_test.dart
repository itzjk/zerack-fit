import 'package:test/test.dart';
import 'package:zerack_core/zerack_core.dart';

ScreeningOutcome _eval({
  required bool active,
  required bool disease,
  Set<WarningSign> signs = const {},
}) =>
    evaluateScreening(ScreeningAnswers(
      exercisesRegularly: active,
      hasKnownCardiometabolicRenalDisease: disease,
      signs: signs,
    ));

void main() {
  const chest = {WarningSign.chestNeckJawArmPain};

  group('no hace ejercicio regular', () {
    test('sin enfermedad ni síntomas: empezar ligero a moderado', () {
      expect(_eval(active: false, disease: false),
          ScreeningOutcome.clearedStartLightToModerate);
    });

    test('con enfermedad conocida: autorización antes de empezar', () {
      expect(_eval(active: false, disease: true),
          ScreeningOutcome.medicalClearanceBeforeStarting);
    });

    test('con síntomas: autorización antes de empezar', () {
      expect(_eval(active: false, disease: false, signs: chest),
          ScreeningOutcome.medicalClearanceBeforeStarting);
    });
  });

  group('hace ejercicio regular', () {
    test('sin enfermedad ni síntomas: continuar', () {
      expect(_eval(active: true, disease: false),
          ScreeningOutcome.clearedContinue);
    });

    test('enfermedad sin síntomas: moderado sí, vigoroso con autorización', () {
      final o = _eval(active: true, disease: true);
      expect(o, ScreeningOutcome.medicalClearanceBeforeVigorous);
      expect(o.allowsTrainingWithoutClearance, isTrue);
      expect(o.allowsVigorous, isFalse);
    });

    test('con síntomas: suspender', () {
      final o = _eval(active: true, disease: true, signs: chest);
      expect(o, ScreeningOutcome.stopAndSeekMedicalClearance);
      expect(o.allowsTrainingWithoutClearance, isFalse);
    });
  });

  test('cualquier signo, en cualquier combinación, bloquea sin autorización',
      () {
    for (final sign in WarningSign.values) {
      for (final active in [true, false]) {
        for (final disease in [true, false]) {
          final o = _eval(active: active, disease: disease, signs: {sign});
          expect(o.allowsTrainingWithoutClearance, isFalse,
              reason: '$sign active=$active disease=$disease');
        }
      }
    }
  });

  group('evaluateSessionSafety', () {
    test('sin signos: continúa', () {
      expect(evaluateSessionSafety({}), SessionSafetyDecision.continueSession);
    });

    test('cualquier signo: para', () {
      for (final sign in WarningSign.values) {
        expect(evaluateSessionSafety({sign}),
            SessionSafetyDecision.stopAndSeekCare);
      }
    });
  });
}
