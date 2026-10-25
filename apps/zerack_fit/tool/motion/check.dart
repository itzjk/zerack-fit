import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:zerack_fit/src/ui/train/exercise_motion.dart';
import 'diagnostics.dart';

void require(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main() {
  try {
    final motions = parseExerciseMotions(
      File('assets/exercise_motion.json').readAsStringSync(),
    );
    require(motions.length == 13, 'Catalog changed: update expected coverage');
    final evidence = <Object>[];
    var checked = 0;
    var affected = 0;
    for (final entry in motions.entries) {
      final m = entry.value;
      final viewport = m.paintBounds;
      var measured = paintedBounds(m, 0);
      var worst = -1.0;
      var worstT = 0.0;
      var outside = 0;
      for (var i = 0; i <= 1000; i++) {
        final t = i / 1000;
        final b = paintedBounds(m, t);
        measured = measured.expandToInclude(b);
        final overflow = [
          0.0,
          -b.left,
          -b.top,
          b.right - 100,
          b.bottom - 100,
        ].reduce(math.max);
        if (overflow > 0.001) outside++;
        if (overflow > worst) {
          worst = overflow;
          worstT = t;
        }
        require(containsRect(viewport, b), '${entry.key} overflows at $t');
        checked++;
      }
      if (outside > 0) affected++;
      evidence.add({
        'id': entry.key,
        'viewport': rectJson(viewport),
        'measured': rectJson(measured),
        'oldOutsideSamples': outside,
        'samples': 1001,
        'maxOverflow': worst,
        'worst': snapshot(m, worstT),
        'poses': [
          for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) snapshot(m, t),
        ],
      });
    }
    final overhead = motions['overhead_press']!;
    require(paintedBounds(overhead, 1).top < -10, 'Negative control failed');
    require(
      !containsRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        paintedBounds(overhead, 1),
      ),
      'Original bug was not detected',
    );
    const interior = ExerciseMotion(
      root: MotionRoot.ankle,
      at: Offset(50, 95),
      props: {'barbell'},
      from: MotionPose(shin: 0, thigh: 0, torso: 0, upper: -80, fore: 350),
      to: MotionPose(shin: 0, thigh: 0, torso: 0, upper: 80, fore: 10),
    );
    final ends = paintedBounds(
      interior,
      0,
    ).expandToInclude(paintedBounds(interior, 1));
    require(
      paintedBounds(interior, 0.5).top < ends.top,
      'Interior extrema fixture failed',
    );
    require(
      containsRect(interior.paintBounds, paintedBounds(interior, 0.5)),
      'Interior extrema missed',
    );
    require(
      (MotionPose.lerp(interior.from, interior.to, 0.5).fore - 360).abs() <
          1e-9,
      'Angle wrapping failed',
    );
    final random = math.Random(24);
    MotionPose pose() => MotionPose(
      shin: random.nextDouble() * 720 - 360,
      thigh: random.nextDouble() * 720 - 360,
      torso: random.nextDouble() * 720 - 360,
      upper: random.nextDouble() * 720 - 360,
      fore: random.nextDouble() * 720 - 360,
    );
    for (var i = 0; i < 100; i++) {
      final m = ExerciseMotion(
        root: MotionRoot.values[i % 2],
        at: const Offset(50, 65),
        props: {
          'barbell',
          'dumbbell',
          'handle',
          'platform',
          'seat',
          'sled',
          'cable',
        },
        from: pose(),
        to: pose(),
        anchor: const Offset(2, -10),
        bench: const Rect.fromLTRB(20, 70, 80, 76),
      );
      final viewport = m.paintBounds;
      for (var f = 0; f <= 100; f++) {
        require(
          containsRect(viewport, paintedBounds(m, f / 100)),
          'Generated motion $i fails at $f',
        );
        checked++;
      }
    }
    final report = {
      'schema': 1,
      'source': 'assets/exercise_motion.json',
      'scope': 'Drawing bounds only. Not a biomechanical validation.',
      'checkedPoses': checked,
      'affectedExercises': affected,
      'exercises': evidence,
    };
    final destination = Platform.environment['MOTION_REPORT_PATH'];
    if (destination != null) {
      File(
        destination,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
    stdout.writeln(
      'PASS: $checked poses, ${motions.length} real exercises, 100 generated motions.',
    );
    stdout.writeln(
      'PASS: negative control, interior extrema, shortest-arc wrapping.',
    );
    stdout.writeln(
      'Original viewport: $affected/${motions.length} exercises exceed their allocated square.',
    );
    exit(0);
  } catch (e, st) {
    stderr.writeln('FAIL: $e\n$st');
    exit(1);
  }
}
