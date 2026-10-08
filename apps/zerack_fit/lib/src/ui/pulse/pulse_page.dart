import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerack_core/zerack_core.dart';

import '../scope.dart';
import '../strings.dart';
import 'red_channel.dart';

/// Pulso en reposo con el dedo sobre la cámara y el flash (beta).
class PulsePage extends StatefulWidget {
  const PulsePage({super.key});

  @override
  State<PulsePage> createState() => _PulsePageState();
}

enum _Phase { intro, measuring, done }

class _PulsePageState extends State<PulsePage> {
  static const duration = Duration(seconds: 30);

  _Phase _phase = _Phase.intro;
  CameraController? _camera;
  final _samples = <PpgSample>[];
  final _watch = Stopwatch();
  Timer? _ticker;
  PulseResult? _result;
  String? _error;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _watch.stop();
    final c = _camera;
    _camera = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.setFlashMode(FlashMode.off);
    } on Object {
      // La cámara ya se cerró.
    }
    await c.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _result = null;
      _samples.clear();
    });
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final c = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ios
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await c.initialize();
      await c.setFlashMode(FlashMode.torch);
      _camera = c;
      _watch
        ..reset()
        ..start();
      await c.startImageStream((img) {
        final red = meanRed(
          format: ios ? FrameFormat.bgra8888 : FrameFormat.yuv420,
          planes: [
            for (final p in img.planes)
              FramePlane(p.bytes, p.bytesPerRow, p.bytesPerPixel),
          ],
          width: img.width,
          height: img.height,
        );
        _samples.add(PpgSample(_watch.elapsed, red));
      });
      setState(() => _phase = _Phase.measuring);
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (_watch.elapsed >= duration) {
          _finish();
        } else if (mounted) {
          setState(() {});
        }
      });
    } on Object {
      await _stop();
      if (mounted) {
        setState(() {
          _phase = _Phase.intro;
          _error = 'No pude usar la cámara. Revisa el permiso en Ajustes.';
        });
      }
    }
  }

  Future<void> _finish() async {
    final samples = List.of(_samples);
    await _stop();
    final r = const PulseEstimator().estimate(samples);
    if (mounted) {
      setState(() {
        _result = r;
        _phase = _Phase.done;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pulso en reposo (beta)')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.measuring => _measuring(context),
          _Phase.done => _done(context),
        },
      ),
    );
  }

  List<Widget> _intro(BuildContext context) => [
    const Icon(Icons.favorite_border, size: 64),
    const SizedBox(height: 16),
    const Text(
      '1. Siéntate y descansa un minuto.\n'
      '2. Cubre por completo la cámara trasera y el flash con la yema del '
      'dedo índice, sin presionar fuerte.\n'
      '3. Quédate quieto 30 segundos.',
    ),
    const SizedBox(height: 16),
    Text(
      'Es una estimación de bienestar, no una medición médica. Si la señal '
      'no es confiable, la app no da un número.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    if (_error != null) ...[
      const SizedBox(height: 16),
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
    const SizedBox(height: 24),
    FilledButton(onPressed: _start, child: const Text('Empezar')),
  ];

  List<Widget> _measuring(BuildContext context) {
    final p = (_watch.elapsed.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final left = (duration - _watch.elapsed).inSeconds.clamp(0, 30);
    return [
      const SizedBox(height: 32),
      Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(value: p, strokeWidth: 10),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'Midiendo… $left s',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
      const Center(child: Text('No muevas el dedo.')),
      const SizedBox(height: 24),
      TextButton(
        onPressed: () async {
          await _stop();
          if (mounted) setState(() => _phase = _Phase.intro);
        },
        child: const Text('Cancelar'),
      ),
    ];
  }

  List<Widget> _done(BuildContext context) {
    final r = _result!;
    final text = Theme.of(context).textTheme;
    if (!r.isOk) {
      return [
        const Icon(Icons.error_outline, size: 64),
        const SizedBox(height: 16),
        Text(Es.pulseFailure(r.failure!)),
        const SizedBox(height: 24),
        FilledButton(onPressed: _start, child: const Text('Intentar de nuevo')),
      ];
    }
    return [
      Center(child: Text('${r.bpm!.round()}', style: text.displayLarge)),
      const Center(child: Text('latidos por minuto (estimado)')),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Calidad de la señal: ${(r.quality * 100).round()} %',
          style: text.bodySmall,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () async {
          await AppScope.of(context).logPulse(r.bpm!);
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const Text('Guardar'),
      ),
      TextButton(onPressed: _start, child: const Text('Medir otra vez')),
    ];
  }
}
