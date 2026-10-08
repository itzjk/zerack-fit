import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../strings.dart';

/// Pide la porción en gramos de un alimento y muestra sus nutrientes.
/// Regresa los gramos elegidos o `null` si se cancela.
Future<double?> showPortionSheet(
  BuildContext context,
  Food food, {
  double initialGrams = 100,
  String? sourceNote,
}) => showModalBottomSheet<double>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PortionSheet(
    food: food,
    initialGrams: initialGrams,
    sourceNote: sourceNote,
  ),
);

class _PortionSheet extends StatefulWidget {
  const _PortionSheet({
    required this.food,
    required this.initialGrams,
    this.sourceNote,
  });
  final Food food;
  final double initialGrams;
  final String? sourceNote;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late final _grams = TextEditingController(
    text: widget.initialGrams.round().toString(),
  );

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_grams.text.replaceAll(',', '.'));
    return (v == null || v <= 0 || v > 5000) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final grams = _value;
    final n = grams == null ? null : f.forGrams(grams);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.name, style: text.titleLarge),
          Text(
            widget.sourceNote ?? 'Datos del USDA FoodData Central',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('portion-grams'),
            controller: _grams,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'g',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          if (f.portions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in f.portions)
                  ActionChip(
                    label: Text('${p.label} (${p.grams.round()} g)'),
                    onPressed: () => setState(
                      () => _grams.text = p.grams.round().toString(),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (n != null)
            NutrientRow(n, key: const Key('portion-nutrients'))
          else
            const Text('Escribe una cantidad entre 1 y 5000 g'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('portion-add'),
              onPressed: grams == null
                  ? null
                  : () => Navigator.of(context).pop(grams),
              child: const Text('Agregar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// kcal y macros en una fila compacta.
class NutrientRow extends StatelessWidget {
  const NutrientRow(this.n, {super.key});
  final Nutrients n;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(value, style: text.titleMedium),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
    return Row(
      children: [
        cell('kcal', '${n.kcal.round()}'),
        cell('proteína', Es.g(n.proteinG)),
        cell('carbohidratos', Es.g(n.carbsG)),
        cell('grasa', Es.g(n.fatG)),
      ],
    );
  }
}
