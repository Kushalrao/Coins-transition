// design_tokens.dart
//
// Exact colors and font helpers ported from DesignTokens.swift and the local
// color set inside TripAnnouncementViewV2.swift. Every hex matches the Swift
// source verbatim. See FLUTTER_PORT_SPEC.md §2 and §3.

import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Colors referenced by TripAnnouncementViewV2.
abstract final class DesignColors {
  // --- From DesignColors (DesignTokens.swift), used by V2 ---
  static const tripCardGradientBottom = Color(0xFFFDD910); // #FDD910
  static const rewardsGradientTop = Color(0xFFE96307); // #E96307
  static const textHighEmphasis = Color(0xFF262B30); // #262B30

  // --- Local to TripAnnouncementViewV2 ---
  static const bgTop = Color(0xFFFFF8EE); // #FFF8EE
  static const bgBottom = Color(0xFFF7F9F4); // #F7F9F4
  static const detailBG = Color(0xFFF8FAF5); // #F8FAF5
  static const imageBG = Color(0xFFFEF8E9); // #FEF8E9
  static const navy = Color(0xFF031223); // #031223
  static const green = Color(0xFF389E0D); // #389E0D
  static const offerBG = Color(0xFFF9F7D1); // #F9F7D1
  static const closeBG = Color(0xFFE9EBE7); // #E9EBE7
  static const balanceInk = Color(0xFF141C20); // #141C20
  static const cardMint = Color(0xFFBDE3DF); // #BDE3DF
  static const alertAmber = Color(0xFFD48806); // #D48806
  static const rewardsBgTop = Color(0xFFEF6004); // #EF6004
  static final rewardsTextWhite = const Color(0xFFFFFFFF).withOpacity(0.88);
  static const rewardsLabel = Color(0xFFFFFBE6); // #FFFBE6
}

/// Lexend Deca weight helpers. The Swift source addresses six PostScript
/// instances of the variable font; here we select the matching wght axis.
abstract final class DesignFont {
  static const _family = 'LexendDeca';

  // Natural line height (matches SwiftUI default). Callers override `height`
  // where the Swift source sets an explicit lineSpacing.
  static TextStyle _style(double size, double wght, Color color) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        color: color,
        fontVariations: [FontVariation('wght', wght)],
      );

  static TextStyle regular(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 400, color);
  static TextStyle medium(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 500, color);
  static TextStyle semibold(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 600, color);
  static TextStyle bold(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 700, color);
  static TextStyle extraBold(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 800, color);
  static TextStyle black(double size, {Color color = const Color(0xFF000000)}) =>
      _style(size, 900, color);
}
