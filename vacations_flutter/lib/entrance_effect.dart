// entrance_effect.dart
//
// Port of EntranceEffect / EntranceState (TripAnnouncementViewV2 §7). A 1.0s
// keyframe entrance for the trip card:
//   offsetY  600 → -30 (0..0.55) → 0 (0.55..1)        [Cubic]
//   scale    0.2 → 0.8 (0..0.55) → 1.0 (0.55..1)      [Cubic]
//   rotation -45 → 0  (0..0.9)   → 0                  [Cubic]   (X axis, anchor bottom)
//   warp     1   → 0.2 (0..0.55) → 0 (0.55..1)        [Cubic]
//   opacity  0   → 1  (0..0.3)   → 1                  [Linear]
//
// `scale`/`rotation` anchor at the bottom; `warp` applies the card_warp shader.
//
// SwiftUI `CubicKeyframe` produces a continuous cubic (Hermite) spline that
// carries momentum THROUGH interior keyframes (e.g. offsetY flies up past -30
// without stopping), easing to rest only at the very start and end. We
// reproduce that with `_cubic()` below — a Hermite spline whose end tangents
// are zero (start/end at rest) and whose interior tangent is the Catmull-Rom
// slope. This matches CubicKeyframe far better than per-segment easeInOut,
// which would (incorrectly) decelerate to a stop at every keyframe.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

/// Total entrance duration: 0.55 + 0.45 = 1.0s.
const Duration kEntranceDuration = Duration(milliseconds: 1000);

/// Evaluates a cubic Hermite spline through `pts` (each [time, value], times
/// ascending, first at t=0) at time `t`. End tangents are 0 (rest); interior
/// tangents use the Catmull-Rom slope — mirroring SwiftUI CubicKeyframe.
double _cubic(List<List<double>> pts, double t) {
  final n = pts.length;
  if (t <= pts.first[0]) return pts.first[1];
  if (t >= pts.last[0]) return pts.last[1];

  // Tangents (value/time) at each point.
  double tangent(int i) {
    if (i == 0 || i == n - 1) return 0.0; // start/end at rest
    return (pts[i + 1][1] - pts[i - 1][1]) / (pts[i + 1][0] - pts[i - 1][0]);
  }

  // Find the segment [i, i+1] containing t.
  var i = 0;
  while (i < n - 1 && !(t >= pts[i][0] && t <= pts[i + 1][0])) {
    i++;
  }
  final t0 = pts[i][0], t1 = pts[i + 1][0];
  final p0 = pts[i][1], p1 = pts[i + 1][1];
  final dt = t1 - t0;
  final u = (t - t0) / dt;
  final m0 = tangent(i), m1 = tangent(i + 1);

  // Hermite basis.
  final u2 = u * u, u3 = u2 * u;
  final h00 = 2 * u3 - 3 * u2 + 1;
  final h10 = u3 - 2 * u2 + u;
  final h01 = -2 * u3 + 3 * u2;
  final h11 = u3 - u2;
  return h00 * p0 + h10 * dt * m0 + h01 * p1 + h11 * dt * m1;
}

double _segLinear(double p, double a, double b, double from, double to) {
  if (p <= a) return from;
  if (p >= b) return to;
  return from + (to - from) * ((p - a) / (b - a));
}

class EntranceEffect extends StatelessWidget {
  final double progress; // 0..1 over kEntranceDuration; 0 = not started
  final double w;
  final double h;
  final ui.FragmentShader? warpShader;
  final Widget child;

  const EntranceEffect({
    super.key,
    required this.progress,
    required this.w,
    required this.h,
    required this.warpShader,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Cubic-spline tracks (offsetY 600→-30→0, scale 0.2→0.8→1.0, warp 1→0.2→0),
    // each with a keyframe at t=0.55 and t=1.0, matching SwiftUI CubicKeyframe.
    final oy = _cubic(const [
      [0.0, 600],
      [0.55, -30],
      [1.0, 0],
    ], progress);
    final scale = _cubic(const [
      [0.0, 0.2],
      [0.55, 0.8],
      [1.0, 1.0],
    ], progress);
    final warp = _cubic(const [
      [0.0, 1.0],
      [0.55, 0.2],
      [1.0, 0.0],
    ], progress);
    // rotation: single CubicKeyframe (-45→0 over 0.9), then holds at 0.
    final rotationDeg = _cubic(const [
      [0.0, -45],
      [0.9, 0],
    ], progress);
    // opacity: LinearKeyframe 0→1 over 0.3, then holds at 1.
    final opacity = _segLinear(progress, 0.0, 0.3, 0, 1);

    // Build inside-out: card → warp → scale(bottom) → rotation(bottom) →
    // offset → opacity (matching the SwiftUI modifier order).
    Widget content = child;

    if (warp > 0.001 && warpShader != null) {
      content = _Warp(shader: warpShader!, w: w, h: h, amount: warp, child: content);
    }

    // scaleEffect(scale, anchor: .bottom)
    content = Transform.scale(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: content,
    );

    // rotation3DEffect(.degrees(rotation), axis: x, anchor: .bottom, perspective: 1.0)
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective (approximation of SwiftUI 1.0)
      ..rotateX(rotationDeg * math.pi / 180);
    content = Transform(
      transform: m,
      alignment: Alignment.bottomCenter,
      child: content,
    );

    // offset(y:) then opacity
    content = Transform.translate(offset: Offset(0, oy), child: content);
    content = Opacity(opacity: opacity.clamp(0.0, 1.0), child: content);

    return content;
  }
}

/// Applies card_warp.frag to its child during the entrance.
class _Warp extends StatelessWidget {
  final ui.FragmentShader shader;
  final double w;
  final double h;
  final double amount;
  final Widget child;

  const _Warp({
    required this.shader,
    required this.w,
    required this.h,
    required this.amount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSampler(
      (image, size, canvas) {
        shader
          ..setFloat(0, size.width) // uSize.x
          ..setFloat(1, size.height) // uSize.y
          ..setFloat(2, amount) // uAmount
          ..setImageSampler(0, image); // uTexture
        canvas.drawRect(
          Offset.zero & size,
          Paint()..shader = shader,
        );
      },
      child: child,
    );
  }
}
