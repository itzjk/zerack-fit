import 'package:flutter/material.dart';
import 'package:zerack_core/zerack_core.dart';

import '../common/portion_sheet.dart';
import '../scope.dart';

/// Busca en la base del USDA. Si [pickOnly] es `true`, regresa el alimento
/// elegido en lugar de registrarlo.
class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key, this.pickOnly = false, this.initialQuery});
  final bool pickOnly;
  final String? initialQuery;

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _choose(Food food) async {
    if (widget.pickOnly) {
      Navigator.of(context).pop(food);
      return;
    }
    final grams = await showPortionSheet(context, food);
    if (grams == null || !mounted) return;
    await AppScope.of(context).addFoodFromDb(food, grams);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final foods = AppScope.of(context).foods;
    final q = _query.text.trim();
    final results = q.isEmpty ? foods.all : foods.search(q, limit: 50);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('food-search'),
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar alimento (ej. tortilla, pollo)',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No está en la base. Prueba con otro nombre o anótalo a mano '
                'desde la pantalla Hoy.',
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) {
                final f = results[i];
                return ListTile(
                  key: Key('food-${f.id}'),
                  title: Text(f.name),
                  subtitle: Text(
                    '${f.per100g.kcal.round()} kcal · '
                    '${f.per100g.proteinG.toStringAsFixed(1)} g proteína '
                    'por 100 g',
                  ),
                  onTap: () => _choose(f),
                );
              },
            ),
    );
  }
}
