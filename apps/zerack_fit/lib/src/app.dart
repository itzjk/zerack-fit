import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/scope.dart';

class ZerackApp extends StatelessWidget {
  const ZerackApp({super.key, required this.state});
  final AppState state;

  static const _seed = Color(0xFF00B37E);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'ZERACK Fit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return state.onboarded ? const HomeShell() : const OnboardingFlow();
  }
}
