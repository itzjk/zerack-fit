import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../ai/claude_client.dart';
import '../../ai/food_scanner.dart';
import '../../data/models.dart';
import '../../services.dart';
import '../common/ai_gate.dart';
import '../common/portion_sheet.dart';
import '../scope.dart';
import 'food_search_page.dart';

/// Escanea un plato con la IA. La IA identifica y estima gramos; los
/// nutrientes salen del USDA y la persona confirma todo antes de guardar.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.picker});
  final Future<Uint8List?> Function(ImageSource source)? picker;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _EditableItem {
  _EditableItem(this.food, this.name, double grams, this.confidence)
    : grams = TextEditingController(text: grams.round().toString());
  Food? food;
  final String name;
  final TextEditingController grams;
  final ScanConfidence confidence;

  double? get gramsValue {
    final v = double.tryParse(grams.text.replaceAll(',', '.'));
    return (v == null || v <= 0 || v > 5000) ? null : v;
  }
}

class _ScanPageState extends State<ScanPage> {
  bool _busy = false;
  String? _error;
  String _note = '';
  List<_EditableItem>? _items;

  @override
  void dispose() {
    for (final i in _items ?? const <_EditableItem>[]) {
      i.grams.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _pick(ImageSource source) async {
    if (widget.picker != null) return widget.picker!(source);
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1568,
      maxHeight: 1568,
      imageQuality: 85,
    );
    return x?.readAsBytes();
  }

  Future<void> _scan(ImageSource source) async {
    final state = AppScope.of(context);
    final ai = ServicesScope.of(context).ai;
    final bytes = await _pick(source);
    if (bytes == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (await ai.scanner(state)).scan(bytes);
      if (!mounted) return;
      setState(() {
        _note = result.note;
        _items = [
          for (final i in result.items)
            _EditableItem(i.food, i.name, i.grams, i.confidence),
        ];
        if (!result.isFood) {
          _error = 'No parece comida. Toma la foto del plato desde arriba.';
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeClaudeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(_EditableItem item) async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(pickOnly: true, initialQuery: item.name),
      ),
    );
    if (food != null) setState(() => item.food = food);
  }

  Nutrients _total() => (_items ?? const <_EditableItem>[]).fold(
    Nutrients.zero,
    (sum, i) => i.food == null || i.gramsValue == null
        ? sum
        : sum + i.food!.forGrams(i.gramsValue!),
  );

  Future<void> _save() async {
    final state = AppScope.of(context);
    for (final i in _items!) {
      if (i.food != null && i.gramsValue != null) {
        await state.addFoodFromDb(
          i.food!,
          i.gramsValue!,
          source: FoodSource.scan,
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear plato')),
      body: AiGate(
        feature: 'escanear tu comida',
        sends: 'la foto del plato',
        child: _busy
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Identificando alimentos…'),
                  ],
                ),
              )
            : _items == null
            ? _intro(context)
            : _results(context),
      ),
    );
  }

  Widget _intro(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.restaurant, size: 64),
      const SizedBox(height: 16),
      const Text(
        'Toma la foto desde arriba, con todo el plato a la vista. La IA '
        'identifica los alimentos y estima las porciones; las calorías salen '
        'de la base del USDA. Revisa y corrige antes de guardar.',
      ),
      if (_error != null) ...[
        const SizedBox(height: 16),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const Key('scan-camera'),
        icon: const Icon(Icons.photo_camera),
        label: const Text('Tomar foto'),
        onPressed: () => _scan(ImageSource.camera),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('scan-gallery'),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Elegir de la galería'),
        onPressed: () => _scan(ImageSource.gallery),
      ),
    ],
  );

  Widget _results(BuildContext context) {
    final state = AppScope.of(context);
    final items = _items!;
    final total = _total();
    final target = state.energyTarget;
    final after = state.todayKcalEaten + total.kcal.round();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (items.isEmpty)
          const Text('No identifiqué alimentos. Intenta con otra foto.'),
        for (final (idx, i) in items.indexed)
          Card(
            key: Key('scan-item-$idx'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.food?.name ?? 'No está en la base: ${i.name}',
                          style: text.titleMedium,
                        ),
                      ),
                      _ConfidenceChip(i.confidence),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: TextField(
                          key: Key('scan-grams-$idx'),
                          controller: i.grams,
                          decoration: const InputDecoration(suffixText: 'g'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (i.food != null && i.gramsValue != null)
                        Text(
                          '${i.food!.forGrams(i.gramsValue!).kcal.round()} '
                          'kcal',
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Cambiar alimento',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _replace(i),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => items.removeAt(idx)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Nota de la IA: $_note', style: text.bodySmall),
        ],
        const SizedBox(height: 16),
        Text('Total del plato', style: text.titleMedium),
        const SizedBox(height: 8),
        NutrientRow(total, key: const Key('scan-total')),
        if (target != null) ...[
          const SizedBox(height: 12),
          Text(
            'Con este plato llevarías $after de ${target.kcal.round()} kcal '
            'de tu meta de hoy.',
            key: const Key('scan-fit'),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('scan-save'),
          onPressed: items.any((i) => i.food != null && i.gramsValue != null)
              ? _save
              : null,
          child: const Text('Guardar en mi día'),
        ),
        TextButton(
          onPressed: () => setState(() => _items = null),
          child: const Text('Tomar otra foto'),
        ),
      ],
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip(this.c);
  final ScanConfidence c;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (c) {
      ScanConfidence.high => ('Seguro', Icons.check_circle_outline),
      ScanConfidence.medium => ('Revisa porción', Icons.help_outline),
      ScanConfidence.low => ('Revisa', Icons.warning_amber),
    };
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
