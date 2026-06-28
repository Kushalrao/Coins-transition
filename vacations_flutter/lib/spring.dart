// spring.dart
//
// Faithful conversion of SwiftUI `.spring(response:dampingFraction:)` to a
// Flutter SpringSimulation. See FLUTTER_PORT_SPEC.md §13.3.
//
//   SwiftUI:  stiffness = (2π / response)^2,  dampingRatio = dampingFraction,
//             mass = 1
//
// Drive an AnimationController from 0→1 with `springSimulation(...)`; read the
// controller's value as the normalized progress `t` and lerp your properties.

import 'dart:math' as math;
import 'package:flutter/physics.dart';

SpringDescription springDescription({
  required double response,
  required double dampingFraction,
  double mass = 1.0,
}) {
  final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  return SpringDescription.withDampingRatio(
    mass: mass,
    stiffness: stiffness,
    ratio: dampingFraction,
  );
}

/// A 0→1 spring simulation matching a SwiftUI spring.
SpringSimulation springSimulation({
  required double response,
  required double dampingFraction,
  double start = 0.0,
  double end = 1.0,
  double velocity = 0.0,
}) {
  return SpringSimulation(
    springDescription(response: response, dampingFraction: dampingFraction),
    start,
    end,
    velocity,
  );
}
