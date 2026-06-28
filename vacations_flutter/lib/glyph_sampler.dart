// glyph_sampler.dart
//
// Port of GlyphSampler.points (TripAnnouncementViewV2.swift). Rasterises a
// single glyph (white on black) and returns the centres of its opaque pixels,
// relative to the glyph's centre, in logical points. Used to shape the particle
// cloud from the real digits. See FLUTTER_PORT_SPEC.md §6a.
//
// Matches the Swift algorithm exactly:
//   • Lexend Deca Black, fontSize 64
//   • render scale = 2
//   • padded size = ceil(textSize) + 4 in each dimension; text drawn at (2,2)
//   • step = max(2, Int(sqrt(w*h*0.35 / maxCount)))
//   • opaque test: gray > 110
//   • point = (x/scale - paddedW/2, y/scale - paddedH/2)

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

abstract final class GlyphSampler {
  static Future<List<Offset>> points({
    required String text,
    required double fontSize,
    required int maxCount,
    double weight = 900, // LexendDeca-Black
  }) async {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'LexendDeca',
          fontSize: fontSize,
          color: const Color(0xFFFFFFFF),
          height: 1.0,
          fontVariations: [ui.FontVariation('wght', weight)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textSize = painter.size;
    final paddedW = textSize.width.ceilToDouble() + 4;
    final paddedH = textSize.height.ceilToDouble() + 4;
    const scale = 2.0;
    final w = (paddedW * scale).toInt();
    final h = (paddedH * scale).toInt();
    if (w <= 0 || h <= 0) return const [];

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Black background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
    // Draw the glyph upright at (2,2) in unscaled coords, after scaling by 2.
    canvas.scale(scale, scale);
    painter.paint(canvas, const Offset(2, 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    if (byteData == null) return const [];
    final buf = byteData.buffer.asUint8List();

    // Step so total opaque samples land near maxCount (glyph covers ~35%).
    final step = math.max(
      2,
      math.sqrt(w * h * 0.35 / maxCount).toInt(),
    );

    final pts = <Offset>[];
    var y = 0;
    while (y < h) {
      var x = 0;
      while (x < w) {
        // RGBA; white text on black → red channel == gray value.
        final gray = buf[(y * w + x) * 4];
        if (gray > 110) {
          pts.add(Offset(
            x / scale - paddedW / 2,
            y / scale - paddedH / 2,
          ));
        }
        x += step;
      }
      y += step;
    }
    return pts;
  }
}
