import 'dart:typed_data';

/// Un plano de imagen de la cámara, sin depender del plugin.
class FramePlane {
  const FramePlane(this.bytes, this.bytesPerRow, [this.bytesPerPixel]);
  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

enum FrameFormat { bgra8888, yuv420 }

/// Brillo promedio del canal rojo (0–255) de un cuadro, muestreando una
/// rejilla de [step] píxeles para no gastar batería.
double meanRed({
  required FrameFormat format,
  required List<FramePlane> planes,
  required int width,
  required int height,
  int step = 8,
}) {
  var sum = 0.0;
  var n = 0;
  switch (format) {
    case FrameFormat.bgra8888:
      final p = planes[0];
      for (var y = 0; y < height; y += step) {
        for (var x = 0; x < width; x += step) {
          final i = y * p.bytesPerRow + x * 4 + 2;
          if (i < p.bytes.length) {
            sum += p.bytes[i];
            n++;
          }
        }
      }
      return n == 0 ? 0 : sum / n;
    case FrameFormat.yuv420:
      // R ≈ Y + 1.402·(V − 128), con V a media resolución.
      final yPlane = planes[0];
      final vPlane = planes.length > 2 ? planes[2] : null;
      var sumV = 0.0;
      var nV = 0;
      for (var y = 0; y < height; y += step) {
        for (var x = 0; x < width; x += step) {
          final i = y * yPlane.bytesPerRow + x;
          if (i < yPlane.bytes.length) {
            sum += yPlane.bytes[i];
            n++;
          }
          if (vPlane != null) {
            final px = vPlane.bytesPerPixel ?? 1;
            final j = (y ~/ 2) * vPlane.bytesPerRow + (x ~/ 2) * px;
            if (j < vPlane.bytes.length) {
              sumV += vPlane.bytes[j];
              nV++;
            }
          }
        }
      }
      if (n == 0) return 0;
      final meanY = sum / n;
      final meanV = nV == 0 ? 128 : sumV / nV;
      return (meanY + 1.402 * (meanV - 128)).clamp(0, 255).toDouble();
  }
}
