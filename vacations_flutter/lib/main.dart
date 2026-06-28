// main.dart
//
// Entry point for the Flutter port of TripAnnouncementViewV2. Mirrors
// VacationsApp.swift, which shows BookingFlowView → TripAnnouncementViewV2.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'trip_announcement_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preload Lexend Deca before the first frame so the rolling ticker renders
  // immediately AND the offscreen glyph rasterization (particle cloud) samples
  // the real digits rather than a fallback/empty glyph.
  final loader = FontLoader('LexendDeca')
    ..addFont(rootBundle.load('assets/fonts/LexendDeca-VF.ttf'));
  await loader.load();
  runApp(const VacationsApp());
}

class VacationsApp extends StatelessWidget {
  const VacationsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Vacations',
      debugShowCheckedModeBanner: false,
      home: TripAnnouncementV2(),
    );
  }
}
