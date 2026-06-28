// trip_announcement_v2.dart
//
// Flutter port of TripAnnouncementViewV2.swift — the three-phase post-booking
// rewards sequence (earned → added → trip). Every value (color, size, padding,
// duration, delay, curve, count) matches the Swift source. See
// FLUTTER_PORT_SPEC.md for the value-for-value mapping.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import 'design_tokens.dart';
import 'entrance_effect.dart';
import 'haptics.dart';
import 'particle_dissolve.dart';
import 'rolling_number.dart';
import 'spring.dart';

enum _RewardPhase { earned, added, trip }

class TripAnnouncementV2 extends StatefulWidget {
  const TripAnnouncementV2({super.key});

  @override
  State<TripAnnouncementV2> createState() => _TripAnnouncementV2State();
}

class _TripAnnouncementV2State extends State<TripAnnouncementV2>
    with TickerProviderStateMixin {
  // ---- Layout constants ----
  static const double cardW = 326;
  static const double cardH = 401;
  static const double numBoxH = 78;

  // ---- Sequence state ----
  _RewardPhase phase = _RewardPhase.earned;
  bool rollEarned = false;
  int balanceCount = 0;
  bool shineActive = false;
  int secondsLeft = 24 * 3600 + 32 * 60 + 27; // 88,347 → 24:32:27
  static const bool textLiftEnabled = true;

  // Particle build
  List<DissolveDot> dissolveDots = const [];
  double bandTop = -40;
  double bandBottom = 40;
  bool dissolveStarted = false;
  Duration _dissolveStartStamp = Duration.zero;

  // Video
  VideoPlayerController? _video;

  // Shader
  ui.FragmentShader? _warpShader;

  // ---- Controllers ----
  late final AnimationController _appearC; // spring 0.5/0.82
  late final AnimationController _liftC; // easeOut 1.1 (numberZoom/lift)
  late final AnimationController _earnedFadeC; // earned label fade out (0.45)
  late final AnimationController _sweepC; // dissolveProgress linear 0.95
  late final AnimationController _pillC; // pill spring 0.42/0.56
  late final AnimationController _headingRevealC; // easeInOut 1.2
  late final AnimationController _shineC; // shineAngle linear 1.9 repeatForever
  late final AnimationController _pulseC; // pillPulse
  late final AnimationController _entranceC; // trip-card entrance 1.0s
  late final AnimationController _headingShownC; // easeOut 0.4
  late final AnimationController _bodyShownC; // easeOut 0.45
  late final AnimationController _tripFadeC; // crossfade 0.55 easeInOut
  late final AnimationController _frameC; // monotonic clock for particles

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _appearC = AnimationController.unbounded(vsync: this);
    _liftC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _earnedFadeC = AnimationController(vsync: this, value: 1.0, duration: const Duration(milliseconds: 450));
    _sweepC = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _pillC = AnimationController.unbounded(vsync: this);
    _headingRevealC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _shineC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
    _pulseC = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _entranceC = AnimationController(vsync: this, duration: kEntranceDuration);
    _headingShownC = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _bodyShownC = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _tripFadeC = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _frameC = AnimationController(vsync: this, duration: const Duration(hours: 1))..forward();

    _initAsync();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsLeft > 0) setState(() => secondsLeft -= 1);
    });
  }

  void _initAsync() {
    // All async prep runs concurrently so none of it delays the timed sequence,
    // which must start promptly (≈0.2s after the first frame) to preserve the
    // timeline. The sequence is resilient if a piece isn't ready yet.
    unawaited(_loadShader());
    unawaited(_initVideo());
    unawaited(_buildDots());
    unawaited(_runSequence());
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/card_warp.frag');
      _warpShader = program.fragmentShader();
    } catch (_) {
      _warpShader = null; // fall back to no-warp if shader fails to compile
    }
  }

  Future<void> _initVideo() async {
    // Coin video — plays once at 0.75×, muted, holds last frame.
    final v = VideoPlayerController.asset('assets/video/ScapiaCoin.mp4');
    _video = v;
    await v.initialize();
    await v.setVolume(0);
    await v.setPlaybackSpeed(0.75);
    await v.setLooping(false);
    if (!mounted) return;
    setState(() {});
    // The coin is hidden (opacity 0) until `appeared`; play as soon as it's
    // ready so it spins/morphs through the earned phase.
    v.play();
  }

  Future<void> _buildDots() async {
    // Build the particle cloud from the real glyphs of "32,800".
    final build = await buildDissolveDots();
    if (!mounted) return;
    setState(() {
      dissolveDots = build.dots;
      bandTop = build.bandTop;
      bandBottom = build.bandBottom;
    });
  }

  // ----------------------------------------------------------------------
  // Master timeline — mirrors runSequence() (FLUTTER_PORT_SPEC.md §4).
  // ----------------------------------------------------------------------
  Future<void> _runSequence() async {
    Future<void> sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

    // t=0.20 — earned screen appears (spring), digits roll, ticker haptics.
    await sleep(200);
    if (!mounted) return;
    _appearC.animateWith(springSimulation(response: 0.5, dampingFraction: 0.82));
    setState(() => rollEarned = true);
    Haptics.shared.tickerBurst();
    await sleep(1600); // let the roll settle
    await sleep(300); // brief hold

    // t=2.10 — phase → added; anticipation lift on the number.
    if (!mounted) return;
    setState(() => phase = _RewardPhase.added);
    _earnedFadeC.reverse(); // "Travel rewards earned" fades out 1→0 over 0.45
    if (textLiftEnabled) {
      _liftC.forward(); // easeOut 1.1: zoom 1→1.06, lift 0→-28
    }
    await sleep(120);

    // t=2.22 — start the disintegration.
    if (!mounted) return;
    setState(() {
      dissolveStarted = true;
      _dissolveStartStamp = _frameC.lastElapsedDuration ?? Duration.zero;
    });
    Haptics.shared.startContinuousLow();

    // Task A — the sweep wave climbs the text (after 0.18s, over 0.95s).
    unawaited(() async {
      await sleep((kDissolveWaveStart * 1000).round());
      if (!mounted) return;
      _sweepC.forward();
    }());

    // Task B — pill springs in, then counts up.
    unawaited(() async {
      await sleep(300);
      if (!mounted) return;
      _pillC.animateWith(springSimulation(response: 0.42, dampingFraction: 0.56));
      await sleep(260); // show 0 for a beat
      await _stepCount(to: 5790, steps: 46, stepMs: 32, set: (v) {
        if (mounted) setState(() => balanceCount = v);
      });
    }());

    // t=3.42 — heading wipes in (easeInOut 1.2).
    await sleep(1200);
    if (!mounted) return;
    _headingRevealC.forward();

    // t=4.62 — rumble stops; border shine + pill pulse.
    await sleep(1200);
    if (!mounted) return;
    Haptics.shared.stopContinuous();
    setState(() => shineActive = true);
    _shineC.repeat(); // linear 1.9 repeatForever
    // pillPulse 1.0 → 1.07 (easeOut 0.28) → 1.0 (easeInOut 0.5). _pulseC runs
    // 0→1 and is mapped to (1.0 + 0.07 * value) where it's read.
    _pulseC.animateTo(1.0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    await sleep(280);
    if (!mounted) return;
    _pulseC.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    await sleep(2700);

    // t=7.60 — crossfade to the trip card and play its entrance.
    if (!mounted) return;
    setState(() => phase = _RewardPhase.trip);
    _tripFadeC.forward();
    await sleep(120);
    if (!mounted) return;
    _entranceC.forward();
    await sleep(550);
    if (!mounted) return;
    _headingShownC.forward();
    await sleep(250);
    if (!mounted) return;
    _bodyShownC.forward();
  }

  /// Steps an integer from 0→target across `steps`, `stepMs` apart, then exact.
  Future<void> _stepCount({
    required int to,
    required int steps,
    required int stepMs,
    required void Function(int) set,
  }) async {
    for (var i = 0; i <= steps; i++) {
      set(to * i ~/ steps);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
    set(to);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    Haptics.shared.stopContinuous();
    _video?.dispose();
    _warpShader?.dispose();
    for (final c in [
      _appearC, _liftC, _earnedFadeC, _sweepC, _pillC, _headingRevealC,
      _shineC, _pulseC, _entranceC, _headingShownC, _bodyShownC, _tripFadeC, _frameC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _grouped(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String get _countdownText {
    final h = secondsLeft ~/ 3600;
    final m = (secondsLeft % 3600) ~/ 60;
    final s = secondsLeft % 60;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(h)} : ${two(m)} : ${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // rewardsScreen.opacity(phase == .trip ? 0 : 1)
          AnimatedBuilder(
            animation: _tripFadeC,
            builder: (_, child) => Opacity(
              opacity: 1 - _tripFadeC.value,
              child: child,
            ),
            child: _rewardsScreen(),
          ),
          // tripScreen.opacity(phase == .trip ? 1 : 0)
          AnimatedBuilder(
            animation: _tripFadeC,
            builder: (_, child) => Opacity(
              opacity: _tripFadeC.value,
              child: IgnorePointer(
                ignoring: _tripFadeC.value < 1,
                child: child,
              ),
            ),
            child: _tripScreen(),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // Rewards screen (phases earned + added) — §10
  // ======================================================================
  Widget _rewardsScreen() {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;

      const artCenterY = 59 + 283 / 2; // 200.5
      const numberY = 352.0 + 40; // 392
      const labelY = 444.0 + 36; // 480
      final pill = Offset(w / 2, 20 + 30); // (w/2, 50)

      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DesignColors.rewardsBgTop, DesignColors.tripCardGradientBottom],
          ),
        ),
        child: Stack(
          children: [
            // Coin video (237×283, radius 16), fades+scales in with `appeared`.
            _centered(
              w / 2,
              artCenterY,
              AnimatedBuilder(
                animation: _appearC,
                builder: (_, __) {
                  final v = _appearC.value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: v,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * v,
                      child: _coinVideo(),
                    ),
                  );
                },
              ),
            ),

            // Earned number (rolls in, masked away by the sweep).
            AnimatedBuilder(
              animation: Listenable.merge([_appearC, _liftC, _sweepC]),
              builder: (_, __) {
                final appearV = _appearC.value.clamp(0.0, 1.0);
                final zoom = textLiftEnabled ? 1 + 0.06 * _liftC.value : 1.0;
                final lift = textLiftEnabled ? -28.0 * _liftC.value : 0.0;
                final maskH = _numberMaskH();
                return _centered(
                  w / 2,
                  numberY + lift,
                  Opacity(
                    opacity: appearV,
                    child: Transform.scale(
                      scale: zoom,
                      child: ClipRect(
                        clipper: _TopClipper(maskH),
                        child: RollingNumber(
                          value: 32800,
                          roll: rollEarned,
                          style: DesignFont.black(64).copyWith(shadows: const [
                            Shadow(color: Color(0x1F000000), offset: Offset(0, 4), blurRadius: 16),
                          ]),
                          color: DesignColors.rewardsTextWhite,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // "Travel rewards earned" — earned phase only.
            AnimatedBuilder(
              animation: Listenable.merge([_appearC, _earnedFadeC]),
              builder: (_, __) {
                final op = _appearC.value.clamp(0.0, 1.0) * _earnedFadeC.value;
                return _centered(
                  w / 2,
                  labelY,
                  Opacity(
                    opacity: op.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: 241,
                      child: Text(
                        'Travel rewards earned',
                        textAlign: TextAlign.center,
                        style: DesignFont.semibold(28, color: DesignColors.rewardsLabel),
                      ),
                    ),
                  ),
                );
              },
            ),

            // "Instantly added to your balance" — left→right wipe reveal.
            AnimatedBuilder(
              animation: _headingRevealC,
              builder: (_, __) {
                return _centered(
                  w / 2,
                  numberY,
                  _wipeReveal(
                    reveal: _headingRevealC.value,
                    child: SizedBox(
                      width: 301,
                      child: Text(
                        'Instantly added to your balance',
                        textAlign: TextAlign.center,
                        style: DesignFont
                            .bold(32, color: DesignColors.rewardsLabel)
                            .copyWith(height: 40 / 32), // lineSpacing 40-32*1.2
                      ),
                    ),
                  ),
                );
              },
            ),

            // Particle disintegration layer.
            if (dissolveStarted)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _frameC,
                    builder: (_, __) {
                      final t = ((_frameC.lastElapsedDuration ?? Duration.zero) -
                              _dissolveStartStamp)
                          .inMicroseconds /
                          1e6;
                      return CustomPaint(
                        painter: ParticleDissolvePainter(
                          dots: dissolveDots,
                          center: Offset(w / 2, numberY),
                          target: pill,
                          t: t,
                          white: const Color(0xFFFFFFFF),
                          gold: DesignColors.alertAmber,
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Top balance pill.
            _centered(
              pill.dx,
              pill.dy,
              AnimatedBuilder(
                animation: Listenable.merge([_pillC, _pulseC, _shineC]),
                builder: (_, __) {
                  final v = _pillC.value.clamp(0.0, 1.0);
                  final pulse = 1.0 + 0.07 * _pulseC.value; // 1→1.07→1
                  return Opacity(
                    opacity: v,
                    child: Transform.scale(
                      scale: v * pulse,
                      child: _balancePill(balanceCount),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _coinVideo() {
    final v = _video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 237,
        height: 283,
        child: (v != null && v.value.isInitialized)
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: v.value.size.width,
                  height: v.value.size.height,
                  child: VideoPlayer(v),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Sweep-mask window height for the number (§6d).
  double _numberMaskH() {
    if (!dissolveStarted) return numBoxH;
    final lineFull = numBoxH / 2 + bandBottom;
    final lineEnd = numBoxH / 2 + bandTop - 3;
    return math.max(0, lineFull - _sweepC.value * (lineFull - lineEnd));
  }

  // Balance pill — §10b.
  Widget _balancePill(int value) {
    // Inner white capsule with content.
    final inner = Container(
      width: 152,
      height: 52,
      padding: const EdgeInsets.only(left: 12, right: 16),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.rectangle),
      child: Row(
        children: [
          Image.asset('assets/images/PillCoin.png',
              width: 32, height: 32, filterQuality: FilterQuality.high),
          const SizedBox(width: 8),
          Text(
            _grouped(value),
            style: DesignFont.extraBold(24, color: DesignColors.balanceInk)
                .copyWith(letterSpacing: 0.96),
          ),
          const Spacer(),
        ],
      ),
    );

    return Container(
      // .shadow(color: white@0.64, radius 22)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.64), blurRadius: 22),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 4px warm gradient ring (outer capsule + padding 4 → inner white).
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DesignColors.rewardsGradientTop.withOpacity(0.55),
                  DesignColors.tripCardGradientBottom.withOpacity(0.55),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: inner,
            ),
          ),
          // Glassy shine overlay (covers the 160×60 outer capsule).
          if (shineActive)
            Positioned.fill(
              child: CustomPaint(
                painter: _ShinePainter(angle: _shineC.value * 2 * math.pi),
              ),
            ),
        ],
      ),
    );
  }

  /// "Instantly added" wipe mask — §10a. A feathered white→clear gradient
  /// (TileMode.clamp) whose feather slides left→right with `reveal`.
  Widget _wipeReveal({required double reveal, required Widget child}) {
    const feather = 150.0;
    return ShaderMask(
      blendMode: BlendMode.modulate,
      shaderCallback: (bounds) {
        final tw = bounds.width;
        final e = (tw + feather) * reveal - feather; // white-solid right edge
        return ui.Gradient.linear(
          Offset(e, 0),
          Offset(e + feather, 0),
          const [
            Color(0xFFFFFFFF), // white @ 1.0   (loc 0)
            Color(0xD9FFFFFF), // white @ 0.85  (loc 0.22)
            Color(0x80FFFFFF), // white @ 0.5   (loc 0.5)
            Color(0x2EFFFFFF), // white @ 0.18  (loc 0.78)
            Color(0x00FFFFFF), // clear         (loc 1.0)
          ],
          const [0.0, 0.22, 0.5, 0.78, 1.0],
          TileMode.clamp,
        );
      },
      child: child,
    );
  }

  // ======================================================================
  // Trip screen (phase trip) — §11
  // ======================================================================
  Widget _tripScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DesignColors.bgTop, DesignColors.bgBottom],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const SizedBox(height: 14),
                // heading (fades in)
                AnimatedBuilder(
                  animation: _headingShownC,
                  builder: (_, child) =>
                      Opacity(opacity: _headingShownC.value, child: child),
                  child: _heading(),
                ),
                const SizedBox(height: 26),
                // trip card with entrance
                AnimatedBuilder(
                  animation: _entranceC,
                  builder: (_, child) => EntranceEffect(
                    progress: _entranceC.value,
                    w: cardW,
                    h: cardH,
                    warpShader: _warpShader,
                    child: child!,
                  ),
                  child: _tripCard(),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _bodyShownC,
                  builder: (_, child) =>
                      Opacity(opacity: _bodyShownC.value, child: child),
                  child: Column(
                    children: [
                      Text(
                        'Special perk for your London trip',
                        style: DesignFont.regular(14, color: Colors.black.withOpacity(0.56)),
                      ),
                      const SizedBox(height: 12),
                      _offerCard(),
                    ],
                  ),
                ),
                ],
              ),
            ),
            // Close button — top-right.
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, right: 16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: DesignColors.closeBG, shape: BoxShape.circle),
                  child: Icon(Icons.close, size: 13, color: Colors.black.withOpacity(0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading() {
    return SizedBox(
      width: 272,
      child: Text(
        'Your flight is successfully booked',
        textAlign: TextAlign.center,
        style: DesignFont.bold(24, color: Colors.black).copyWith(height: 32 / 24),
      ),
    );
  }

  // Trip card — §11b.
  Widget _tripCard() {
    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 87),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        // Two stacked fills (Swift: white RoundedRectangle, then a 50%-opacity
        // mint→yellow gradient on top), with the content above. `color` and
        // `gradient` can't share one BoxDecoration (gradient wins), so layer
        // them explicitly to preserve the white base.
        child: Stack(
          alignment: Alignment.topCenter, // ZStack(alignment: .top)
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DesignColors.cardMint.withOpacity(0.5),
                      DesignColors.tripCardGradientBottom.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  SizedBox(width: 310, height: 321, child: _tripDetails()),
                  const SizedBox(height: 8),
                  SizedBox(width: 302, height: 52, child: _coinsPill()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // §11c
  Widget _tripDetails() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: DesignColors.detailBG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plane image area, height 113.
            SizedBox(
              height: 113,
              child: ClipRect(
                child: Container(
                  color: DesignColors.imageBG,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 204,
                    child: Image.asset('assets/images/FlightPlane.png', fit: BoxFit.fitWidth),
                  ),
                ),
              ),
            ),
            // Info block.
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/EmiratesLogo.png', width: 90, fit: BoxFit.contain),
                      const Spacer(),
                      Row(
                        children: [
                          Text('PNR:', style: DesignFont.regular(12, color: Colors.black.withOpacity(0.6))),
                          const SizedBox(width: 6),
                          CustomPaint(
                            painter: _DashedRRectPainter(
                              color: Colors.black.withOpacity(0.33),
                              radius: 4,
                              dash: 3,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text('ASD62D', style: DesignFont.regular(12, color: Colors.black)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('London to Delhi', style: DesignFont.semibold(20, color: Colors.black)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SvgPicture.asset('assets/images/CalendarIcon.svg', width: 16, height: 16),
                      const SizedBox(width: 4),
                      Text('June 27, Sunday',
                          style: DesignFont.regular(14, color: Colors.black.withOpacity(0.6))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Name 1, Name 2',
                      style: DesignFont.regular(12, color: Colors.black.withOpacity(0.6))),
                ],
              ),
            ),
            const Spacer(),
            // "View booking details" pill.
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.only(left: 20, right: 8, top: 12, bottom: 12),
                  decoration: const BoxDecoration(
                    color: DesignColors.navy,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View booking details',
                          style: DesignFont.medium(14, color: Colors.white)),
                      const SizedBox(width: 4),
                      SvgPicture.asset('assets/images/ArrowRight.svg', width: 20, height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // §11d
  Widget _coinsPill() {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(26)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/PillCoin.png',
              width: 32, height: 32, filterQuality: FilterQuality.high),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Coins earned', style: DesignFont.medium(14, color: Colors.black.withOpacity(0.8))),
              Row(
                children: [
                  SvgPicture.asset('assets/images/BoltFill.svg', width: 12, height: 12),
                  Text('Instantly added',
                      style: DesignFont.regular(12, color: DesignColors.alertAmber)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('5,790',
                  style: DesignFont.medium(14, color: Colors.black).copyWith(letterSpacing: 0.56)),
              Text('Worth Rs1152',
                  style: DesignFont.regular(10, color: Colors.black.withOpacity(0.6))),
            ],
          ),
        ],
      ),
    );
  }

  // §11e
  Widget _offerCard() {
    return Container(
      width: 358,
      height: 177,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 40),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(color: Colors.white),
            // Left image region (170×177).
            ClipRect(
              child: SizedBox(
                width: 170,
                height: 177,
                child: Container(
                  color: DesignColors.offerBG,
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: const Offset(-8, 0),
                      child: SizedBox(
                        width: 210,
                        child: Image.asset('assets/images/StayHut.png', fit: BoxFit.fitWidth),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Title — position(x: 186+147/2, y: 16+20).
            _centered(
              186 + 147 / 2,
              16 + 20,
              SizedBox(
                width: 147,
                child: Text(
                  'Flat ₹2,500 off on your stay',
                  style: DesignFont.semibold(14, color: DesignColors.green).copyWith(height: 20 / 14),
                ),
              ),
            ),
            // Subtitle — position(x: 186+140/2, y: 60+16).
            _centered(
              186 + 140 / 2,
              60 + 16,
              SizedBox(
                width: 140,
                child: Text(
                  'Explore from 1000+ stays',
                  style: DesignFont.regular(12, color: Colors.black.withOpacity(0.8)).copyWith(height: 16 / 12),
                ),
              ),
            ),
            // Countdown — position(x: 186+140/2, y: 127+19).
            _centered(
              186 + 140 / 2,
              127 + 19,
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REWARD EXPIRES IN',
                        style: DesignFont.regular(10, color: Colors.black.withOpacity(0.55))
                            .copyWith(letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(_countdownText,
                        style: DesignFont.medium(14, color: DesignColors.textHighEmphasis)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Centers `child` (at its intrinsic size) on point (cx, cy) inside a Stack —
  /// the Flutter equivalent of SwiftUI `.position(x:y:)`.
  Widget _centered(double cx, double cy, Widget child) {
    return Positioned(
      left: cx,
      top: cy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }
}

// ---- Clip the number to its top `height` (the sweep mask). ----
class _TopClipper extends CustomClipper<Rect> {
  final double height;
  const _TopClipper(this.height);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, height);
  @override
  bool shouldReclip(covariant _TopClipper old) => old.height != height;
}

// ---- Glassy pill-border shine — §10b shine overlay. ----
class _ShinePainter extends CustomPainter {
  final double angle; // radians
  const _ShinePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Constant faint glass rim.
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.22),
    );

    final gleam = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(angle),
      colors: [
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0.35),
        Colors.white,
        Colors.white,
        Colors.white.withOpacity(0.35),
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0),
      ],
      stops: const [0.0, 0.32, 0.42, 0.49, 0.51, 0.58, 0.68, 1.0],
    ).createShader(rect);

    // Soft bloom.
    canvas.drawRRect(
      rrect.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader = gleam
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Crisp gleam.
    canvas.drawRRect(
      rrect.deflate(1.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = gleam,
    );
  }

  @override
  bool shouldRepaint(covariant _ShinePainter old) => old.angle != angle;
}

// ---- Dashed rounded-rect border for the PNR chip (dash [3]). ----
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  const _DashedRRectPainter({required this.color, required this.radius, required this.dash});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(
          metric.extractPath(dist, math.min(next, metric.length)),
          paint,
        );
        dist = next + dash; // gap == dash
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => false;
}
