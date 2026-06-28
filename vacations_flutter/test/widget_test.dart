// Smoke test: the app builds and mounts the rewards sequence screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:vacations_flutter/main.dart';
import 'package:vacations_flutter/trip_announcement_v2.dart';

void main() {
  testWidgets('App mounts TripAnnouncementV2', (WidgetTester tester) async {
    await tester.pumpWidget(const VacationsApp());
    expect(find.byType(TripAnnouncementV2), findsOneWidget);
  });
}
