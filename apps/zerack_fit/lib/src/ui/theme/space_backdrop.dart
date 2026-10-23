import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'zerack_theme.dart';

class SpaceBackdrop extends StatefulWidget {
  const SpaceBackdrop({super.key, required this.child, this.animated = true});
  final Widget child;
  final bool animated;

  @override
  State<SpaceBackdrop> createState() => _SpaceBackdropState();
}

class _SpaceBackdropState extends State<SpaceBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  late final _Sky _sky;

  @override
  void initState() {
    super.initState();
    _sky = _Sky(math.Random(23));
    _ticker = createTicker((d) => _clock.value = d.inMicroseconds / 1e6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final run = widget.animated && !reduce;
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) _ticker.stop();
  }

  @override
  void didUpdateWidget(SpaceBackdrop old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Zk.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SkyPainter(_sky, _clock),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  _Star(this.x, this.y, this.radius, this.phase, this.speed, this.drift);
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double speed;
  final double drift;
}

class _Sky {
  _Sky(math.Random r) {
    for (var i = 0; i < 110; i++) {
      final big = r.nextDouble() > 0.84;
      final layer = r.nextDouble();
      stars.add(
        _Star(
          r.nextDouble(),
          r.nextDouble(),
          big ? 1.0 + r.nextDouble() * 0.9 : 0.4 + r.nextDouble() * 0.6,
          r.nextDouble() * math.pi * 2,
          0.5 + r.nextDouble() * 1.4,
          layer < 0.5 ? 0.0035 : (layer < 0.85 ? 0.008 : 0.015),
        ),
      );
    }
  }
  final stars = <_Star>[];
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.sky, this.clock) : super(repaint: clock);
  final _Sky sky;
  final ValueNotifier<double> clock;

  static const _cell = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _grid(canvas, size);
    _stars(canvas, size);
    _meteor(canvas, size);
  }

  void _grid(Canvas canvas, Size size) {
    final fade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00FFFFFF),
          Color(0x0BFFFFFF),
          Color(0x0BFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, 0.14, 0.86, 1],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1
      ..isAntiAlias = false;
    final path = Path();
    for (var x = _cell / 2; x < size.width; x += _cell) {
      path
        ..moveTo(x, 0)
        ..lineTo(x, size.height);
    }
    for (var y = _cell / 2; y < size.height; y += _cell) {
      path
        ..moveTo(0, y)
        ..lineTo(size.width, y);
    }
    canvas.drawPath(path, fade..style = PaintingStyle.stroke);
  }

  void _stars(Canvas canvas, Size size) {
    final t = clock.value;
    final paint = Paint();
    for (final s in sky.stars) {
      final x = ((s.x + s.drift * t / 10) % 1.0) * size.width;
      final y = (((s.y - s.drift * t / 28) % 1.0) + 1.0) % 1.0 * size.height;
      final a = 0.14 + 0.34 * (0.5 + 0.5 * math.sin(t * s.speed + s.phase));
      paint.color = const Color(0xFFE4ECF8).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), s.radius, paint);
    }
  }

  void _meteor(Canvas canvas, Size size) {
    const period = 13.0;
    const life = 1.1;
    final t = clock.value;
    final k = (t % period) - 3.0;
    if (k < 0 || k > life) return;
    final n = (t / period).floor();
    final r = math.Random(n * 7919 + 13);
    final p = k / life;
    final sx = size.width * (0.05 + r.nextDouble() * 0.6);
    final sy = size.height * (0.04 + r.nextDouble() * 0.3);
    final dx = size.width * 0.34;
    final dy = size.height * 0.2;
    final head = Offset(sx + dx * p, sy + dy * p);
    final tail = Offset(head.dx - dx * 0.16, head.dy - dy * 0.16);
    final alpha = math.sin(p * math.pi) * 0.8;
    final paint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          const Color(0x00FFFFFF),
          const Color(0xFFFFFFFF).withValues(alpha: alpha),
        ],
      ).createShader(Rect.fromPoints(tail, head));
    canvas.drawLine(tail, head, paint);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.sky != sky;
}
