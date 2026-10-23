import 'package:flutter/material.dart';

import 'zerack_theme.dart';

class ZkWordmark extends StatelessWidget {
  const ZkWordmark({super.key, this.suffix});
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ZERACK',
          style: TextStyle(
            fontFamily: Zk.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.2,
            color: Zk.text,
            shadows: Zk.glowText,
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 10),
          Text(
            suffix!.toUpperCase(),
            style: const TextStyle(
              fontFamily: Zk.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
              color: Zk.cyan,
            ),
          ),
        ],
      ],
    );
  }
}

class ZkPageTitle extends StatelessWidget {
  const ZkPageTitle(this.title, {super.key, this.eyebrow});
  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ZkEyebrow(eyebrow!),
          if (eyebrow != null) const SizedBox(height: 8),
          Text(title, style: text.headlineMedium),
        ],
      ),
    );
  }
}

class ZkEyebrow extends StatelessWidget {
  const ZkEyebrow(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Zk.cyan,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Zk.cyan, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: Zk.fontFamily,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.6,
            color: Color(0x80FFFFFF),
          ),
        ),
      ],
    );
  }
}

class ZkHeroIcon extends StatelessWidget {
  const ZkHeroIcon(this.icon, {super.key, this.size = 64});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: size + 32,
        height: size + 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Zk.cyanSoft,
          border: Border.all(color: Zk.cyanLine),
          boxShadow: const [
            BoxShadow(color: Color(0x3322D3EE), blurRadius: 30),
          ],
        ),
        child: Icon(icon, size: size * 0.6, color: Zk.cyan),
      ),
    );
  }
}

class ZkSectionLabel extends StatelessWidget {
  const ZkSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Align(alignment: Alignment.centerLeft, child: ZkEyebrow(label)),
    );
  }
}
