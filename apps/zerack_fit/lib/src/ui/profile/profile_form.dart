import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../data/models.dart';
import '../strings.dart';

/// Formulario de perfil. Se usa en el onboarding y al editar.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, this.initial, required this.onSaved});

  final UserProfile? initial;
  final Future<void> Function(UserProfile) onSaved;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late BiologicalSex? _sex = widget.initial?.sex;
  late ActivityLevel _activity =
      widget.initial?.activity ?? ActivityLevel.sedentary;
  late final _age = TextEditingController(
    text: widget.initial?.ageYears.toString(),
  );
  late final _weight = TextEditingController(
    text: _fmt(widget.initial?.weightKg),
  );
  late final _height = TextEditingController(
    text: _fmt(widget.initial?.heightCm),
  );

  static String? _fmt(double? v) => v == null
      ? null
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  String? Function(String?) _range(num min, num max, String unit) => (v) {
    final n = _parse(v ?? '');
    if (n == null) return 'Escribe un número';
    if (n < min || n > max) return 'Entre $min y $max $unit';
    return null;
  };

  Future<void> _submit() async {
    if (_sex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige tu sexo biológico')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await widget.onSaved(
      UserProfile(
        sex: _sex!,
        ageYears: _parse(_age.text)!.round(),
        weightKg: _parse(_weight.text)!,
        heightCm: _parse(_height.text)!,
        activity: _activity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sexo biológico', style: text.titleMedium),
          Text(
            'La fórmula de gasto en reposo lo necesita.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<BiologicalSex>(
            key: const Key('profile-sex'),
            emptySelectionAllowed: true,
            segments: [
              for (final s in BiologicalSex.values)
                ButtonSegment(value: s, label: Text(Es.sex(s))),
            ],
            selected: {?_sex},
            onSelectionChanged: (s) =>
                setState(() => _sex = s.isEmpty ? null : s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('profile-age'),
            controller: _age,
            decoration: const InputDecoration(labelText: 'Edad (años)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: _range(18, 100, 'años'),
          ),
          TextFormField(
            key: const Key('profile-weight'),
            controller: _weight,
            decoration: const InputDecoration(labelText: 'Peso (kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numeric,
            validator: _range(25, 350, 'kg'),
          ),
          TextFormField(
            key: const Key('profile-height'),
            controller: _height,
            decoration: const InputDecoration(labelText: 'Estatura (cm)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numeric,
            validator: _range(100, 250, 'cm'),
          ),
          const SizedBox(height: 24),
          Text('Nivel de actividad', style: text.titleMedium),
          RadioGroup<ActivityLevel>(
            groupValue: _activity,
            onChanged: (v) => setState(() => _activity = v ?? _activity),
            child: Column(
              children: [
                for (final a in ActivityLevel.values)
                  RadioListTile<ActivityLevel>(
                    key: Key('activity-${a.name}'),
                    value: a,
                    title: Text(Es.activity(a)),
                    subtitle: Text(Es.activityHint(a)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _submit,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
