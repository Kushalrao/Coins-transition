// haptics.dart
//
// Best-effort port of Haptics.swift (§8). Flutter's HapticFeedback cannot set
// impact intensity (Swift uses 0.85) or play a CoreHaptics continuous rumble
// (Swift uses intensity 0.32 / sharpness 0.18). We approximate:
//   • tickerBurst()        — 11 medium impacts over 1.15s (count/timing exact)
//   • startContinuousLow() — periodic light impacts as a stand-in rumble
//   • stopContinuous()     — stops the rumble timer
//
// A platform channel to CoreHaptics would be the faithful route; see
// FLUTTER_PORT_SPEC.md §8 / §14.

import 'dart:async';
import 'package:flutter/services.dart';

class Haptics {
  Haptics._();
  static final Haptics shared = Haptics._();

  Timer? _continuous;

  /// A short run of medium impacts to accompany the earned-amount ticker.
  /// count 11, over 1.15s (interval = max(0.04, 1.15/11) ≈ 0.1045s).
  Future<void> tickerBurst({int count = 11, double over = 1.15}) async {
    final interval = Duration(
      microseconds: ((over / count).clamp(0.04, double.infinity) * 1e6).round(),
    );
    for (var i = 0; i < count; i++) {
      HapticFeedback.mediumImpact();
      await Future.delayed(interval);
    }
  }

  /// Begins a low-intensity "rumble" stand-in (real CoreHaptics continuous is
  /// unavailable in pure Flutter). Fires light impacts at a fast cadence.
  void startContinuousLow() {
    _continuous?.cancel();
    _continuous = Timer.periodic(const Duration(milliseconds: 60), (_) {
      HapticFeedback.selectionClick();
    });
  }

  void stopContinuous() {
    _continuous?.cancel();
    _continuous = null;
  }
}
