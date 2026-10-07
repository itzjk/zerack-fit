import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/data/app_state.dart';
import 'src/data/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(SharedPrefsStore(SharedPreferencesAsync()));
  await state.load();
  runApp(ZerackApp(state: state));
}
