// rolling_number.dart
//
// Port of RollingNumberView / RollingDigit (TripAnnouncementViewV2.swift §5).
// Displays a fixed amount whose digits roll into place ticker-style when `roll`
// flips true. The number does NOT count up — it simply rolls in.
//
//   • digit cell 41 × 78, comma cell 20 × 78
//   • each digit: a 0..9 (×2) strip offset to row (10 + digit) — a full spin
//   • spring(response: 1.0, dampingFraction: 0.82).delay(idx * 0.07)

import 'package:flutter/widgets.dart';
import 'spring.dart';

class RollingNumber extends StatelessWidget {
  final int value;
  final bool roll;
  final TextStyle style; // already carries family/size/weight
  final Color color;
  final double digitWidth;
  final double digitHeight;
  final double commaWidth;

  const RollingNumber({
    super.key,
    required this.value,
    required this.roll,
    required this.style,
    required this.color,
    this.digitWidth = 41,
    this.digitHeight = 78,
    this.commaWidth = 20,
  });

  List<String> get _chars {
    // Decimal grouping with ",".
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString().split('');
  }

  @override
  Widget build(BuildContext context) {
    final chars = _chars;
    final ts = style.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < chars.length; idx++)
          if (_isDigit(chars[idx]))
            _RollingDigit(
              digit: int.parse(chars[idx]),
              width: digitWidth,
              height: digitHeight,
              style: ts,
              roll: roll,
              delay: idx * 0.07,
            )
          else
            SizedBox(
              width: commaWidth,
              height: digitHeight,
              child: Center(child: Text(chars[idx], style: ts)),
            ),
      ],
    );
  }

  static bool _isDigit(String c) {
    if (c.length != 1) return false;
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39; // '0'..'9'
  }
}

class _RollingDigit extends StatefulWidget {
  final int digit;
  final double width;
  final double height;
  final TextStyle style;
  final bool roll;
  final double delay;

  const _RollingDigit({
    required this.digit,
    required this.width,
    required this.height,
    required this.style,
    required this.roll,
    required this.delay,
  });

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    if (widget.roll) _start();
  }

  @override
  void didUpdateWidget(covariant _RollingDigit old) {
    super.didUpdateWidget(old);
    if (widget.roll && !old.roll) _start();
  }

  void _start() {
    // 0→1 spring matching SwiftUI .spring(response: 1.0, dampingFraction: 0.82),
    // delayed by `delay`.
    Future.delayed(
      Duration(microseconds: (widget.delay * 1e6).round()),
      () {
        if (!mounted) return;
        _c.animateWith(springSimulation(
          response: 1.0,
          dampingFraction: 0.82,
        ));
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // roll == false → row 0 ("0"); true → row (10 + digit).
    final target = -(10 + widget.digit) * widget.height;
    return ClipRect(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final offsetY = target * _c.value; // _c.value 0→~1 (spring)
            // The 20-row strip is taller than the 78pt window; OverflowBox lets
            // it exceed (top-aligned) while the ClipRect clips to the window.
            return OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 20; i++)
                      SizedBox(
                        width: widget.width,
                        height: widget.height,
                        child: Center(
                          child: Text('${i % 10}', style: widget.style),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
