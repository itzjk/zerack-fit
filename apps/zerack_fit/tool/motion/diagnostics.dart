import 'dart:math' as math;
import 'dart:ui';
import 'package:zerack_fit/src/ui/train/exercise_motion.dart';

Rect paintedBounds(ExerciseMotion m, double t) {
  final j = Joints.solve(m, MotionPose.lerp(m.from, m.to, t));
  Rect point(Offset p, double r) => Rect.fromCircle(center: p, radius: r);
  var b = const Rect.fromLTRB(3.4, 94.9, 96.6, 96.1);
  for (final p in [j.ankle, j.knee, j.hip, j.shoulder, j.elbow, j.wrist]) {
    b = b.expandToInclude(point(p, 3));
  }
  b = b.expandToInclude(point(j.head, 9));
  if (m.props.contains('barbell')) b = b.expandToInclude(point(j.wrist, 6));
  if (m.props.contains('dumbbell')) {
    b = b.expandToInclude(
      Rect.fromCenter(center: j.wrist, width: 11, height: 6),
    );
  }
  if (m.props.contains('handle')) {
    b = b.expandToInclude(
      Rect.fromCenter(center: j.wrist, width: 2, height: 8),
    );
  }
  if (m.bench case final bench?) {
    b = b.expandToInclude(bench.inflate(0.6));
    for (final x in [bench.left + 4, bench.right - 4]) {
      b = b.expandToInclude(point(Offset(x, 95.5), 0.6));
    }
  }
  if (m.props.contains('seat')) {
    b = b.expandToInclude(
      Rect.fromLTRB(
        j.hip.dx - 10.6,
        math.min(j.hip.dy + 2.4, 94.9),
        j.hip.dx + 8.6,
        math.max(j.hip.dy + 3.6, 96.1),
      ),
    );
  }
  if (m.props.contains('sled')) {
    b = b.expandToInclude(
      Rect.fromLTRB(
        j.hip.dx - 14.6,
        j.hip.dy - 6.6,
        j.hip.dx + 10.6,
        j.hip.dy + 10.6,
      ),
    );
  }
  if (m.props.contains('platform')) {
    final d = Offset(math.cos(-0.9), math.sin(-0.9)) * 8;
    b = b.expandToInclude(point(j.ankle - d, 0.6));
    b = b.expandToInclude(point(j.ankle + d, 0.6));
  }
  if (m.props.contains('cable') && m.anchor != null) {
    b = b.expandToInclude(point(m.anchor!, 2.2));
  }
  return b;
}

bool containsRect(Rect outer, Rect inner) =>
    outer.left <= inner.left &&
    outer.top <= inner.top &&
    outer.right >= inner.right &&
    outer.bottom >= inner.bottom;

List<double> rectJson(Rect r) => [r.left, r.top, r.right, r.bottom];

Map<String, Object> snapshot(ExerciseMotion m, double t) {
  final j = Joints.solve(m, MotionPose.lerp(m.from, m.to, t));
  final points = {
    'ankle': j.ankle,
    'knee': j.knee,
    'hip': j.hip,
    'shoulder': j.shoulder,
    'head': j.head,
    'elbow': j.elbow,
    'wrist': j.wrist,
  };
  return {
    't': t,
    'joints': points.map((k, p) => MapEntry(k, [p.dx, p.dy])),
  };
}
