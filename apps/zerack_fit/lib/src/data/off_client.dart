import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zerack_core/zerack_core.dart';

/// Consulta Open Food Facts por código de barras. Solo se envía el código.
///
/// Los datos de Open Food Facts los captura la comunidad (licencia ODbL); la
/// app los marca como tales y no los mezcla con la base del USDA.
class OpenFoodFactsClient {
  OpenFoodFactsClient(this._http);
  final http.Client _http;

  static const userAgent = 'ZERACK Fit/0.2 (github.com/itzjk/zerack-fit)';
  static final _barcode = RegExp(r'^\d{8,14}$');

  static bool isValidBarcode(String code) => _barcode.hasMatch(code);

  /// `null` si el producto no existe o no trae calorías por 100 g.
  Future<Food?> lookup(String barcode) async {
    if (!isValidBarcode(barcode)) {
      throw ArgumentError.value(barcode, 'barcode', 'código inválido');
    }
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode',
      {'fields': 'product_name,product_name_es,nutriments,serving_quantity'},
    );
    final res = await _http
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw http.ClientException('Open Food Facts: ${res.statusCode}', uri);
    }
    return parse(barcode, res.body);
  }

  static Food? parse(String barcode, String body) {
    final j = jsonDecode(body) as Map<String, Object?>;
    if (j['status'] != 1) return null;
    final p = j['product'] as Map<String, Object?>? ?? const {};
    final n = p['nutriments'] as Map<String, Object?>? ?? const {};
    double? v(String k) {
      final x = n[k];
      if (x is num) return x.toDouble();
      if (x is String) return double.tryParse(x);
      return null;
    }

    final kcal = v('energy-kcal_100g');
    if (kcal == null || kcal < 0 || kcal > 900) return null;
    final name = [p['product_name_es'], p['product_name']]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => 'Producto $barcode');
    final serving = (p['serving_quantity'] as num?)?.toDouble();
    return Food(
      // Negativo para no chocar con los fdc_id del USDA.
      id: -int.parse(barcode.substring(barcode.length - 9)),
      name: name,
      category: 'empaquetado',
      sourceDescription: 'Open Food Facts $barcode',
      per100g: Nutrients(
        kcal: kcal,
        proteinG: v('proteins_100g') ?? 0,
        fatG: v('fat_100g') ?? 0,
        carbsG: v('carbohydrates_100g') ?? 0,
        fiberG: v('fiber_100g'),
      ),
      portions: [
        if (serving != null && serving > 0 && serving < 2000)
          Portion('1 porción', serving),
      ],
    );
  }
}
