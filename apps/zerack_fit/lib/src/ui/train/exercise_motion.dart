import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/zerack_theme.dart';

const exerciseMotionAsset = 'assets/exercise_motion.json';

/// Pose de perfil: ángulos absolutos en grados (0 = arriba, 90 = adelante,
/// 180 = abajo). Ver el `_doc` de `assets/exercise_motion.json`.
class MotionPose {
  const MotionPose({
    required this.shin,
    required this.thigh,
    required this.torso,
    required this.upper,
    required this.fore,
  });

  final double shin;
  final double thigh;
  final double torso;
  final double upper;
  final double fore;

  factory MotionPose.fromJson(Map<String, Object?> j) => MotionPose(
    shin: (j['shin'] as num).toDouble(),
    thigh: (j['thigh'] as num).toDouble(),
    torso: (j['torso'] as num).toDouble(),
    upper: (j['upper'] as num).toDouble(),
    fore: (j['fore'] as num).toDouble(),
  );

  /// Interpola por el arco más corto para que un brazo no dé la vuelta por
  /// arriba al pasar de 180° a −150°.
  static MotionPose lerp(MotionPose a, MotionPose b, double t) {
    double one(double x, double y) {
      final delta = (y - x + 180) % 360 - 180;
      return x + delta * t;
    }

    return MotionPose(
      shin: one(a.shin, b.shin),
      thigh: one(a.thigh, b.thigh),
      torso: one(a.torso, b.torso),
      upper: one(a.upper, b.upper),
      fore: one(a.fore, b.fore),
    );
  }
}

enum MotionRoot { ankle, hip }

class ExerciseMotion {
  const ExerciseMotion({
    required this.root,
    required this.at,
    required this.props,
    required this.from,
    required this.to,
    this.bench,
    this.anchor,
  });

  final MotionRoot root;
  final Offset at;
  final Set<String> props;
  final MotionPose from;
  final MotionPose to;
  final Rect? bench;
  final Offset? anchor;

  factory ExerciseMotion.fromJson(Map<String, Object?> j) {
    Offset pt(Object? v) {
      final l = (v as List<Object?>).cast<num>();
      return Offset(l[0].toDouble(), l[1].toDouble());
    }

    final frames = (j['frames'] as List<Object?>).cast<Map<String, Object?>>();
    final bench = (j['bench'] as List<Object?>?)?.cast<num>();
    return ExerciseMotion(
      root: j['root'] == 'hip' ? MotionRoot.hip : MotionRoot.ankle,
      at: pt(j['at']),
      props: {for (final p in j['props'] as List<Object?>) p as String},
      from: MotionPose.fromJson(frames[0]),
      to: MotionPose.fromJson(frames[1]),
      bench: bench == null
          ? null
          : Rect.fromLTRB(
              bench[0].toDouble(),
              bench[1].toDouble(),
              bench[2].toDouble(),
              bench[3].toDouble(),
            ),
      anchor: j['anchor'] == null ? null : pt(j['anchor']),
    );
  }
}

Map<String, ExerciseMotion> parseExerciseMotions(String raw) {
  final j = jsonDecode(raw) as Map<String, Object?>;
  return {
    for (final e in j.entries)
      if (!e.key.startsWith('_'))
        e.key: ExerciseMotion.fromJson(e.value as Map<String, Object?>),
  };
}

Future<Map<String, ExerciseMotion>>? _cache;

/// Carga una sola vez las poses del asset.
Future<Map<String, ExerciseMotion>> loadExerciseMotions(AssetBundle bundle) =>
    _cache ??= bundle
        .loadString(exerciseMotionAsset)
        .then(parseExerciseMotions);

/// Posiciones de las articulaciones en el lienzo de 100×100.
class Joints {
  const Joints(
    this.ankle,
    this.knee,
    this.hip,
    this.shoulder,
    this.head,
    this.elbow,
    this.wrist,
  );
  final Offset ankle;
  final Offset knee;
  final Offset hip;
  final Offset shoulder;
  final Offset head;
  final Offset elbow;
  final Offset wrist;

  static const shinLength = 22.0;
  static const thighLength = 22.0;
  static const torsoLength = 30.0;
  static const neckLength = 3.0;
  static const headRadius = 6.0;
  static const upperArmLength = 16.0;
  static const forearmLength = 15.0;

  static Offset _step(Offset p, double degrees, double length) {
    final r = degrees * math.pi / 180;
    return p + Offset(math.sin(r), -math.cos(r)) * length;
  }

  factory Joints.solve(ExerciseMotion m, MotionPose f) {
    final Offset ankle, knee, hip;
    if (m.root == MotionRoot.ankle) {
      ankle = m.at;
      knee = _step(ankle, f.shin, shinLength);
      hip = _step(knee, f.thigh, thighLength);
    } else {
      hip = m.at;
      knee = _step(hip, f.thigh, thighLength);
      ankle = _step(knee, f.shin, shinLength);
    }
    final shoulder = _step(hip, f.torso, torsoLength);
    final head = _step(shoulder, f.torso, neckLength + headRadius);
    final elbow = _step(shoulder, f.upper, upperArmLength);
    final wrist = _step(elbow, f.fore, forearmLength);
    return Joints(ankle, knee, hip, shoulder, head, elbow, wrist);
  }
}

/// Animación de un ejercicio que va y viene entre sus dos posiciones.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({
    super.key,
    required this.exerciseId,
    this.period = const Duration(milliseconds: 1800),
  });

  final String exerciseId;
  final Duration period;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  Future<Map<String, ExerciseMotion>>? _motions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motions ??= loadExerciseMotions(DefaultAssetBundle.of(context));
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Se detiene cuando otra pantalla queda encima, para no gastar batería.
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (reduce) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!visible) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: FutureBuilder<Map<String, ExerciseMotion>>(
        future: _motions,
        builder: (context, snap) {
          final m = snap.data?[widget.exerciseId];
          if (m == null) return const SizedBox.shrink();
          return Semantics(
            label: 'Animación del ejercicio',
            image: true,
            child: RepaintBoundary(
              child: CustomPaint(painter: _MotionPainter(m, _curve)),
            ),
          );
        },
      ),
    );
  }
}

class _MotionPainter extends CustomPainter {
  _MotionPainter(this.motion, this.t) : super(repaint: t);

  final ExerciseMotion motion;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.scale(s);
    final j = Joints.solve(
      motion,
      MotionPose.lerp(motion.from, motion.to, t.value),
    );

    final prop = Paint()
      ..color = Zk.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = Zk.faint
      ..strokeWidth = 0.6;

    // Piso.
    canvas.drawLine(const Offset(4, 95.5), const Offset(96, 95.5), prop);

    final bench = motion.bench;
    if (bench != null) {
      canvas.drawRect(bench, prop);
      canvas.drawLine(
        bench.bottomLeft + const Offset(4, 0),
        Offset(bench.left + 4, 95.5),
        prop,
      );
      canvas.drawLine(
        bench.bottomRight - const Offset(4, 0),
        Offset(bench.right - 4, 95.5),
        prop,
      );
    }
    if (motion.props.contains('seat')) {
      final y = j.hip.dy + 3;
      canvas.drawLine(Offset(j.hip.dx - 10, y), Offset(j.hip.dx + 8, y), prop);
      canvas.drawLine(Offset(j.hip.dx, y), Offset(j.hip.dx, 95.5), prop);
    }
    if (motion.props.contains('sled')) {
      canvas.drawLine(
        j.hip + const Offset(-14, 10),
        j.hip + const Offset(10, -6),
        prop,
      );
    }
    if (motion.props.contains('platform')) {
      final n = Offset(math.cos(-0.9), math.sin(-0.9)) * 8;
      canvas.drawLine(j.ankle - n, j.ankle + n, prop);
    }
    final anchor = motion.anchor;
    if (anchor != null && motion.props.contains('cable')) {
      canvas.drawLine(j.wrist, anchor, thin);
      canvas.drawCircle(anchor, 1.6, prop);
    }

    // Cuerpo con brillo cian, estilo de la app.
    final glow = Paint()
      ..color = Zk.cyan.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()
      ..color = Zk.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(j.ankle.dx, j.ankle.dy)
      ..lineTo(j.knee.dx, j.knee.dy)
      ..lineTo(j.hip.dx, j.hip.dy)
      ..lineTo(j.shoulder.dx, j.shoulder.dy)
      ..moveTo(j.shoulder.dx, j.shoulder.dy)
      ..lineTo(j.elbow.dx, j.elbow.dy)
      ..lineTo(j.wrist.dx, j.wrist.dy);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, body);
    canvas.drawCircle(j.head, Joints.headRadius, glow);
    canvas.drawCircle(j.head, Joints.headRadius, body);

    // Peso en la mano.
    final weight = Paint()
      ..color = Zk.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (motion.props.contains('barbell')) {
      canvas.drawCircle(j.wrist, 5, weight);
      canvas.drawCircle(j.wrist, 1.2, weight..style = PaintingStyle.fill);
    }
    if (motion.props.contains('dumbbell')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: j.wrist, width: 9, height: 4),
          const Radius.circular(1),
        ),
        weight,
      );
    }
    if (motion.props.contains('handle')) {
      canvas.drawLine(
        j.wrist - const Offset(0, 3),
        j.wrist + const Offset(0, 3),
        weight,
      );
    }
  }

  @override
  bool shouldRepaint(_MotionPainter old) => old.motion != motion || old.t != t;
}
