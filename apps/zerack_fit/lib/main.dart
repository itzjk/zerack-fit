import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/data/app_state.dart';
import 'src/data/food_repository.dart';
import 'src/data/store.dart';
import 'src/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final foods = await loadFoodIndex(rootBundle);
  final state = AppState(
    SharedPrefsStore(SharedPreferencesAsync()),
    foods: foods,
  );
  await state.load();
  runApp(ZerackApp(state: state, services: Services.platform()));
}
