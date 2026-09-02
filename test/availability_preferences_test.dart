import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus/models/availability_window.dart';
import 'package:focus/models/study_preferences.dart';
import 'package:focus/screens/availability_screen.dart';
import 'package:focus/screens/study_preferences_screen.dart';

void main() {
  final mondayMorning = AvailabilityWindow(
    id: 'monday-morning',
    day: StudyDay.monday,
    startTime: StudyTime(8 * 60),
    endTime: StudyTime(10 * 60),
  );

  test('creates an availability window with exact times', () {
    expect(mondayMorning.startTime.hour, 8);
    expect(mondayMorning.endTime.hour, 10);
  });

  test('rejects invalid availability time ranges', () {
    expect(
      () => AvailabilityWindow(
        id: 'invalid',
        day: StudyDay.monday,
        startTime: StudyTime(10 * 60),
        endTime: StudyTime(10 * 60),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('detects overlapping availability while allowing adjacent windows', () {
    final overlapping = AvailabilityWindow(
      id: 'overlap',
      day: StudyDay.monday,
      startTime: StudyTime(9 * 60),
      endTime: StudyTime(11 * 60),
    );
    final adjacent = AvailabilityWindow(
      id: 'adjacent',
      day: StudyDay.monday,
      startTime: StudyTime(10 * 60),
      endTime: StudyTime(12 * 60),
    );

    expect(hasOverlappingAvailability([mondayMorning], overlapping), isTrue);
    expect(hasOverlappingAvailability([mondayMorning], adjacent), isFalse);
  });

  test('creates and updates study preferences independently of availability', () {
    const preferences = StudyPreferences();
    final updated = preferences.copyWith(
      preferredStudyPeriod: PreferredStudyPeriod.evening,
      preferredSessionMinutes: 60,
      restDays: {StudyDay.sunday},
    );

    expect(updated.preferredStudyPeriod, PreferredStudyPeriod.evening);
    expect(updated.preferredSessionMinutes, 60);
    expect(updated.restDays, {StudyDay.sunday});
  });

  testWidgets('displays configured availability', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AvailabilityScreen(initialWindows: [mondayMorning])),
    );

    expect(find.text('Monday'), findsOneWidget);
    expect(find.textContaining('–'), findsOneWidget);
  });

  testWidgets('displays configured study preferences', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudyPreferencesScreen(
          initialPreferences: StudyPreferences(
            preferredStudyPeriod: PreferredStudyPeriod.evening,
            preferredSessionMinutes: 90,
            preferredBreakMinutes: 15,
            maximumDailyStudyMinutes: 180,
            restDays: {StudyDay.sunday},
          ),
        ),
      ),
    );

    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('90 minutes'), findsOneWidget);
    expect(find.text('3 hours'), findsOneWidget);
  });
}
