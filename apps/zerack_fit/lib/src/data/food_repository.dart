import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

const foodsAsset = 'assets/foods_es.json';

/// Carga la base de alimentos generada por `tools/foods/build_foods.py`.
Future<FoodIndex> loadFoodIndex(AssetBundle bundle) async {
  final raw = await bundle.loadString(foodsAsset);
  return parseFoodIndex(raw);
}

FoodIndex parseFoodIndex(String raw) {
  final j = jsonDecode(raw) as Map<String, Object?>;
  final foods = [
    for (final f in (j['foods'] as List<Object?>).cast<Map<String, Object?>>())
      Food.fromJson(f),
  ];
  return FoodIndex(foods);
}
