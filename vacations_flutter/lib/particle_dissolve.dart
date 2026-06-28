// particle_dissolve.dart
//
// Port of the particle disintegration from TripAnnouncementViewV2.swift:
//   • DissolveDot                — one particle sampled from a glyph pixel (§6b)
//   • buildDissolveDots          — makeDissolveDots() pass 1 + 2 (§6a)
//   • ParticleDissolvePainter    — ParticleDissolveView per-frame render (§6c)
//
// Every range, probability, count and constant matches the Swift source.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'glyph_sampler.dart';

/// One particle sampled from a glyph pixel.
class DissolveDot {
  final Offset origin; // start, relative to the number's centre
  final double orbitAngle; // base angle on the halo ellipse around the pill
  final double orbitA; // horizontal radius
  final double orbitB; // vertical radius
  final double orbitSpeed; // slow drift (rad/s) once settled
  final bool settles; // stays as the halo, or fades out on arrival
  final double arc; // sideways bow along the path
  final double size;
  final bool gold;
  final double delay;
  final double dur;
  final double jamp; // settle jitter amplitude ("riddle")
  final double jfreq;
  final double jphase;
  final double twFreq; // twinkle frequency
  final double twPhase;

  const DissolveDot({
    required this.origin,
    required this.orbitAngle,
    required this.orbitA,
    required this.orbitB,
    required this.orbitSpeed,
    required this.settles,
    required this.arc,
    required this.size,
    required this.gold,
    required this.delay,
    required this.dur,
    required this.jamp,
    required this.jfreq,
    required this.jphase,
    required this.twFreq,
    required this.twPhase,
  });
}

/// Result of building the cloud: the particles plus the glyph-pixel band
/// (relative to the number's centre) used to drive the sweep mask.
class DissolveBuild {
  final List<DissolveDot> dots;
  final double bandTop;
  final double bandBottom;
  const DissolveBuild(this.dots, this.bandTop, this.bandBottom);
}

// Sequence constants (shared with the screen).
const double kDissolveWaveStart = 0.18;
const double kDissolveWaveSpread = 0.95;

/// makeDissolveDots(): samples "32,800" at LexendDeca-Black 64 and turns every
/// glyph pixel into ~3 particles with a bottom→top wave delay. See §6a.
Future<DissolveBuild> buildDissolveDots() async {
  final rng = math.Random();
  const chars = ['3', '2', ',', '8', '0', '0'];
  const digitW = 41.0, commaW = 20.0, fontSize = 64.0;
  final widths = chars.map((c) => c == ',' ? commaW : digitW).toList();
  final total = widths.reduce((a, b) => a + b);

  // Pass 1 — collect every glyph-pixel origin (centred on the number).
  final origins = <Offset>[];
  var x = -total / 2;
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    final cw = widths[i];
    final cx = x + cw / 2;
    final pts = await GlyphSampler.points(
      text: ch,
      fontSize: fontSize,
      maxCount: ch == ',' ? 180 : 1020,
    );
    for (final p in pts) {
      origins.add(Offset(cx + p.dx, p.dy));
    }
    x += cw;
  }
  if (origins.isEmpty) return const DissolveBuild([], -40, 40);

  // Pass 2 — origins → particles with a bottom→top wave delay.
  final ys = origins.map((o) => o.dy);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final span = math.max(1.0, maxY - minY);
  final bandTop = minY;
  final bandBottom = maxY;

  double rand(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);

  final dots = <DissolveDot>[];
  for (final o in origins) {
    // 3 particles per sampled glyph pixel → ~3× denser rise.
    for (var k = 0; k < 3; k++) {
      if (rng.nextDouble() < 0.2) continue; // drop 20% of total
      final jx = rand(-2.5, 2.5);
      final jy = rand(-2.5, 2.5);
      final frac = (maxY - o.dy) / span; // 0 = bottom, 1 = top
      final ang = rand(0, 2 * math.pi);
      final rr = rand(0, 14); // tight band hugging the pill
      const a = 82.0, b = 32.0; // halo radii ≈ pill border
      dots.add(DissolveDot(
        origin: Offset(o.dx + jx, o.dy + jy),
        orbitAngle: ang,
        orbitA: a + rr,
        orbitB: b + rr,
        orbitSpeed: rand(0.1, 0.22), // very slow drift around the pill
        settles: rng.nextDouble() < 0.034, // ~1/3 of before stay as the halo
        arc: (o.dx >= 0 ? 1 : -1) * rand(30, 85) + rand(-10, 10),
        size: rand(2.0, 4.0),
        gold: rng.nextDouble() < 0.7, // 70% gold, 30% white
        delay: kDissolveWaveStart + frac * kDissolveWaveSpread + rand(0, 0.04),
        dur: rand(0.95, 1.5),
        jamp: rand(1.5, 4.5),
        jfreq: rand(1.4, 2.8),
        jphase: rand(0, 2 * math.pi),
        twFreq: rand(2.0, 4.0),
        twPhase: rand(0, 2 * math.pi),
      ));
    }
  }
  return DissolveBuild(dots, bandTop, bandBottom);
}

/// ParticleDissolveView: draws every particle each frame. `t` is seconds since
/// the dissolve started. See §6c — born/travel/settle math copied exactly.
class ParticleDissolvePainter extends CustomPainter {
  final List<DissolveDot> dots;
  final Offset center; // number centre
  final Offset target; // pill centre
  final double t; // seconds since start
  final Color white;
  final Color gold;

  ParticleDissolvePainter({
    required this.dots,
    required this.center,
    required this.target,
    required this.t,
    required this.white,
    required this.gold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final d in dots) {
      // A particle is "born" only when the sweep line reaches its row.
      final life = t - d.delay;
      if (life <= 0) continue;
      final prog = math.min(life / d.dur, 1.0);
      final sx = center.dx + d.origin.dx;
      final sy = center.dy + d.origin.dy;
      // Settle point slowly orbits the pill.
      final oa = d.orbitAngle + d.orbitSpeed * t;
      final gx = target.dx + math.cos(oa) * d.orbitA;
      final gy = target.dy + math.sin(oa) * d.orbitB;

      double px, py, op, r;
      if (prog < 1) {
        // Travel: ease up toward the (slowly moving) settle point.
        final e = 1 - math.pow(1 - prog, 3).toDouble();
        px = sx + (gx - sx) * e + d.arc * math.sin(prog * math.pi);
        py = sy + (gy - sy) * e;
        final bornOp = math.min(life / 0.1, 1.0); // quick fade-in at birth
        final arriveFade = d.settles
            ? 1.0
            : (prog < 0.65 ? 1.0 : math.max(0.0, 1 - (prog - 0.65) / 0.35));
        op = bornOp * arriveFade;
        r = d.size * (1 - 0.2 * prog);
      } else {
        if (!d.settles) continue; // absorbed; gone
        final st = life - d.dur;
        px = gx + math.sin(t * d.jfreq + d.jphase) * d.jamp;
        py = gy + math.cos(t * d.jfreq * 1.2 + d.jphase) * d.jamp;
        final twinkle = 0.5 + 0.5 * math.sin(t * d.twFreq + d.twPhase);
        final settleIn = math.min(st / 0.25, 1.0);
        op = (1 - settleIn) + settleIn * (0.4 * (0.7 + 0.3 * twinkle));
        r = d.size * 0.85;
      }
      if (op <= 0.02) continue;
      paint.color = (d.gold ? gold : white).withOpacity(op.clamp(0.0, 1.0));
      // Swift fills an ellipse in a rect of (x - r/2, y - r/2, r, r).
      canvas.drawOval(
        Rect.fromLTWH(px - r / 2, py - r / 2, r, r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticleDissolvePainter old) => true;
}
