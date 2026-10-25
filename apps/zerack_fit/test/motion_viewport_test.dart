import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../tool/motion/diagnostics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerack_fit/src/ui/train/exercise_motion.dart';

void main() {
  final raw = File('assets/exercise_motion.json').readAsStringSync();
  final motions = parseExerciseMotions(raw);
  final evidence = <Object>[];

  test('all painted geometry fits throughout all 13 real exercise cycles', () {
    expect(motions.length, 13);
    for (final entry in motions.entries) {
      final m = entry.value;
      final viewport = m.paintBounds;
      var outside = 0;
      var worst = -1.0;
      var worstT = 0.0;
      var measured = paintedBounds(m, 0);
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
        expect(
          containsRect(viewport, b),
          isTrue,
          reason: '${entry.key} at $t: $b outside $viewport',
        );
      }
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
    final path = Platform.environment['MOTION_REPORT_PATH'];
    if (path != null) {
      File(path).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'schema': 1,
          'source': 'assets/exercise_motion.json',
          'scope': 'Drawing bounds only. Not a biomechanical validation.',
          'exercises': evidence,
        }),
      );
    }
  });

  test('negative control detects the original overhead overflow', () {
    final m = motions['overhead_press']!;
    final end = paintedBounds(m, 1);
    expect(end.top, lessThan(-10));
    expect(containsRect(const Rect.fromLTWH(0, 0, 100, 100), end), isFalse);
    expect(containsRect(m.paintBounds, end), isTrue);
  });

  test('swept bounds include interior extrema and wrapped angles', () {
    const m = ExerciseMotion(
      root: MotionRoot.ankle,
      at: Offset(50, 95),
      props: {'barbell'},
      from: MotionPose(shin: 0, thigh: 0, torso: 0, upper: -80, fore: 350),
      to: MotionPose(shin: 0, thigh: 0, torso: 0, upper: 80, fore: 10),
    );
    final middle = paintedBounds(m, 0.5);
    final endpoints = paintedBounds(m, 0).expandToInclude(paintedBounds(m, 1));
    expect(middle.top, lessThan(endpoints.top));
    expect(containsRect(m.paintBounds, middle), isTrue);
    expect(MotionPose.lerp(m.from, m.to, 0.5).fore, closeTo(360, 1e-9));
  });

  test('conservative bounds hold for varied angles and both roots', () {
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
      for (var f = 0; f <= 100; f++) {
        expect(
          containsRect(m.paintBounds, paintedBounds(m, f / 100)),
          isTrue,
          reason: 'generated motion $i at $f',
        );
      }
    }
  });

  testWidgets('animation paints in small and wide layouts', (tester) async {
    for (final width in [100.0, 320.0, 768.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: width,
              child: const ExerciseAnimation(exerciseId: 'overhead_press'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
