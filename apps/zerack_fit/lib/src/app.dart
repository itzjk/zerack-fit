import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'services.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/scope.dart';

class ZerackApp extends StatelessWidget {
  const ZerackApp({super.key, required this.state, required this.services});
  final AppState state;
  final Services services;

  static const seed = Color(0xFF00B37E);

  static ThemeData _theme(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
    useMaterial3: true,
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
  );

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: services,
      child: AppScope(
        state: state,
        child: MaterialApp(
          title: 'ZERACK Fit',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const _Root(),
        ),
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
