import 'package:flutter/material.dart';
import 'package:zerack_core/zerack_core.dart';

import '../profile/profile_form.dart';
import '../scope.dart';
import '../strings.dart';

/// Aviso → perfil → screening. Cada paso se guarda al confirmar, así que si la
/// app se cierra a medias se retoma donde iba.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.disclaimerAccepted) return const _DisclaimerStep();
    if (state.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu perfil')),
        body: ProfileForm(onSaved: state.saveProfile),
      );
    }
    return const ScreeningStep();
  }
}

class _DisclaimerStep extends StatefulWidget {
  const _DisclaimerStep();

  @override
  State<_DisclaimerStep> createState() => _DisclaimerStepState();
}

class _DisclaimerStepState extends State<_DisclaimerStep> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text('ZERACK Fit', style: text.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Entrenamiento que se adapta a tu salud.',
              style: text.titleMedium,
            ),
            const SizedBox(height: 32),
            Text(Es.disclaimer, style: text.bodyLarge),
            const SizedBox(height: 24),
            CheckboxListTile(
              key: const Key('disclaimer-check'),
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: const Text('Entiendo y acepto'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('disclaimer-continue'),
              onPressed: _accepted
                  ? () => AppScope.of(context).acceptDisclaimer()
                  : null,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuestionario previo (ACSM 2015). Muestra el resultado antes de guardarlo.
class ScreeningStep extends StatefulWidget {
  const ScreeningStep({super.key, this.onDone});

  /// Se llama después de guardar (p. ej. para cerrar la pantalla al repetir).
  final VoidCallback? onDone;

  @override
  State<ScreeningStep> createState() => _ScreeningStepState();
}

class _ScreeningStepState extends State<ScreeningStep> {
  bool? _exercises;
  bool? _disease;
  final Set<WarningSign> _signs = {};
  ScreeningAnswers? _result;

  ScreeningAnswers? get _answers => _exercises == null || _disease == null
      ? null
      : ScreeningAnswers(
          exercisesRegularly: _exercises!,
          hasKnownCardiometabolicRenalDisease: _disease!,
          signs: Set.of(_signs),
        );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de entrenar')),
      body: result == null ? _questions(context) : _outcome(context, result),
    );
  }

  Widget _questions(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Estas preguntas siguen el screening del American College of Sports '
          'Medicine (2015).',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 24),
        _YesNo(
          keyPrefix: 'exercises',
          question:
              'En los últimos 3 meses, ¿has hecho ejercicio planeado al '
              'menos 30 minutos, 3 días por semana, a intensidad moderada?',
          value: _exercises,
          onChanged: (v) => setState(() => _exercises = v),
        ),
        const SizedBox(height: 24),
        _YesNo(
          keyPrefix: 'disease',
          question:
              '¿Te han diagnosticado enfermedad del corazón, diabetes '
              '(tipo 1 o 2) o enfermedad de los riñones?',
          value: _disease,
          onChanged: (v) => setState(() => _disease = v),
        ),
        const SizedBox(height: 24),
        Text(
          '¿Tienes alguno de estos síntomas? Marca todos los que apliquen.',
          style: text.titleMedium,
        ),
        for (final s in WarningSign.values)
          CheckboxListTile(
            key: Key('sign-${s.name}'),
            value: _signs.contains(s),
            onChanged: (v) =>
                setState(() => v == true ? _signs.add(s) : _signs.remove(s)),
            title: Text(Es.sign(s)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('screening-submit'),
          onPressed: _answers == null
              ? null
              : () => setState(() => _result = _answers),
          child: const Text('Ver resultado'),
        ),
      ],
    );
  }

  Widget _outcome(BuildContext context, ScreeningAnswers answers) {
    final outcome = evaluateScreening(answers);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          outcome.allowsTrainingWithoutClearance
              ? Icons.check_circle_outline
              : Icons.medical_services_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(Es.outcomeTitle(outcome), style: text.headlineSmall),
        const SizedBox(height: 12),
        Text(Es.outcomeBody(outcome), style: text.bodyLarge),
        const SizedBox(height: 32),
        FilledButton(
          key: const Key('screening-save'),
          onPressed: () async {
            await AppScope.of(context).saveScreening(answers);
            widget.onDone?.call();
          },
          child: const Text('Continuar'),
        ),
        TextButton(
          onPressed: () => setState(() => _result = null),
          child: const Text('Cambiar respuestas'),
        ),
      ],
    );
  }
}

class _YesNo extends StatelessWidget {
  const _YesNo({
    required this.keyPrefix,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          key: Key('$keyPrefix-choice'),
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: true, label: Text('Sí')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: {?value},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
        ),
      ],
    );
  }
}
