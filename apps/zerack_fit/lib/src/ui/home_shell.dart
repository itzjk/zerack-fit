import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../ai/claude_client.dart' show assistantName;
import 'assistant/assistant_page.dart';
import 'profile/profile_page.dart';
import 'progress/progress_page.dart';
import 'theme/zerack_theme.dart';
import 'today/today_page.dart';
import 'train/train_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    TodayPage(),
    TrainPage(),
    AssistantPage(),
    ProgressPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _GlassBar(
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              label: 'Hoy',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center),
              label: 'Entrenar',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'IA',
              tooltip: assistantName,
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x8C0A0A0C),
            border: Border(top: BorderSide(color: Zk.hairline)),
          ),
          child: child,
        ),
      ),
    );
  }
}
