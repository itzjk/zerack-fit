import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'services.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/scope.dart';
import 'ui/theme/space_backdrop.dart';
import 'ui/theme/zerack_theme.dart';

class ZerackApp extends StatelessWidget {
  const ZerackApp({
    super.key,
    required this.state,
    required this.services,
    this.animatedBackdrop = true,
  });
  final AppState state;
  final Services services;
  final bool animatedBackdrop;

  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Zk.black,
    systemNavigationBarIconBrightness: Brightness.light,
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
          theme: ZerackTheme.build(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: SpaceBackdrop(
              animated: animatedBackdrop,
              child: _Column(child: child ?? const SizedBox.shrink()),
            ),
          ),
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

class _Column extends StatelessWidget {
  const _Column({required this.child});
  final Widget child;

  static const maxWidth = 680.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth <= maxWidth) return child;
        return Center(
          child: SizedBox(
            width: maxWidth,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x59000000),
                border: Border.symmetric(
                  vertical: BorderSide(color: Zk.hairline),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
