import 'dart:convert';
import 'dart:typed_data';

import 'package:zerack_core/zerack_core.dart';

import 'claude_client.dart';

enum ScanConfidence { low, medium, high }

/// Un alimento que la IA reconoció en la foto.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.grams,
    required this.confidence,
    this.food,
  });

  /// Nombre que dio la IA (útil si no está en la base).
  final String name;

  /// Porción estimada por la IA. La persona la confirma o la corrige.
  final double grams;
  final ScanConfidence confidence;

  /// Alimento de la base USDA. `null` si la IA no encontró equivalente.
  final Food? food;

  Nutrients? get nutrients => food?.forGrams(grams);
}

class ScanResult {
  const ScanResult({
    required this.isFood,
    required this.items,
    required this.note,
  });
  final bool isFood;
  final List<ScannedItem> items;
  final String note;
}

/// Analiza la foto de un plato. **La IA solo identifica alimentos y estima
/// gramos**; las calorías y macros siempre salen de la base del USDA.
class FoodScanner {
  FoodScanner(this._client, this._foods);

  final ClaudeClient _client;
  final FoodIndex _foods;

  static const maxGrams = 2000.0;

  String get _system {
    final catalog = [
      for (final f in _foods.all) '${f.id}|${f.name}',
    ].join('\n');
    return '''
Eres el analizador de comida de la app $assistantName. Recibes la foto de un plato o alimento.

Tu trabajo:
1. Decide si la foto muestra comida o bebida (is_food).
2. Identifica cada alimento visible por separado (tortillas, frijoles, carne, salsa...).
3. Para cada uno elige el id del CATÁLOGO que mejor corresponda. Si nada corresponde razonablemente, usa food_id null y escribe el nombre.
4. Estima los gramos de la porción visible usando referencias del plato, cubiertos o manos. Sé conservador y realista.
5. confidence: high si el alimento y la porción son claros, medium si hay duda en la porción, low si dudas qué es.

No calcules calorías: la app las calcula con datos del USDA.
En "note" escribe una frase corta en español con lo que no pudiste ver bien (salsas, aceite, relleno), o deja la cadena vacía.

CATÁLOGO (id|nombre):
$catalog''';
  }

  static const _schema = {
    'type': 'json_schema',
    'schema': {
      'type': 'object',
      'properties': {
        'is_food': {'type': 'boolean'},
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'food_id': {
                'anyOf': [
                  {'type': 'integer'},
                  {'type': 'null'},
                ],
              },
              'name': {'type': 'string'},
              'grams': {'type': 'number'},
              'confidence': {
                'type': 'string',
                'enum': ['low', 'medium', 'high'],
              },
            },
            'required': ['food_id', 'name', 'grams', 'confidence'],
            'additionalProperties': false,
          },
        },
        'note': {'type': 'string'},
      },
      'required': ['is_food', 'items', 'note'],
      'additionalProperties': false,
    },
  };

  /// Tipo de imagen por su firma de bytes. La API acepta JPEG, PNG, GIF y
  /// WebP.
  static String? mediaTypeOf(Uint8List b) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 12 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return 'image/gif';
    return null;
  }

  Future<ScanResult> scan(Uint8List image) async {
    final mediaType = mediaTypeOf(image);
    if (mediaType == null) {
      throw const ClaudeBadRequest('Formato de imagen no soportado');
    }
    final msg = await _client.create(
      system: _system,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Encode(image),
              },
            },
            {'type': 'text', 'text': 'Analiza este plato.'},
          ],
        },
      ],
      outputFormat: _schema,
      maxTokens: 4000,
    );
    return parse(msg.text);
  }

  /// Valida la respuesta: descarta ids que no existen y gramos imposibles.
  ScanResult parse(String raw) {
    final Map<String, Object?> j;
    try {
      j = jsonDecode(raw) as Map<String, Object?>;
    } on Object {
      throw const ClaudeBadRequest('La IA respondió en un formato inesperado');
    }
    final items = <ScannedItem>[];
    for (final it in (j['items'] as List<Object?>? ?? const [])) {
      if (it is! Map<String, Object?>) continue;
      final grams = (it['grams'] as num?)?.toDouble() ?? 0;
      if (grams <= 0 || grams > maxGrams || grams.isNaN) continue;
      final id = (it['food_id'] as num?)?.toInt();
      items.add(
        ScannedItem(
          name: (it['name'] as String?)?.trim() ?? '',
          grams: grams.roundToDouble(),
          confidence: ScanConfidence.values.firstWhere(
            (c) => c.name == it['confidence'],
            orElse: () => ScanConfidence.low,
          ),
          food: id == null ? null : _foods.byId(id),
        ),
      );
    }
    return ScanResult(
      isFood: j['is_food'] as bool? ?? items.isNotEmpty,
      items: items,
      note: (j['note'] as String?)?.trim() ?? '',
    );
  }
}
