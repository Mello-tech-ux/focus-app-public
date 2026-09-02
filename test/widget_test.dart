import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus/main.dart';
import 'package:focus/models/study_module.dart';
import 'package:focus/screens/modules_screen.dart';

void main() {
  testWidgets('shows the FOCUS welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusApp());

    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('Enter FOCUS'), findsOneWidget);
 await tester.pump(const Duration(milliseconds: 500)); });

  testWidgets('shows a module card with key information',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModulesScreen(
          initialModules: const [
            StudyModule(
              id: 'mat101',
              name: 'Calculus 1',
              code: 'MAT101',
              difficulty: ModuleDifficulty.difficult,
              priority: ModulePriority.high,
              weeklyStudyTargetHours: 4,
              color: Color(0xFF315E51),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Calculus 1'), findsOneWidget);
    expect(find.text('MAT101'), findsOneWidget);
    expect(find.text('Difficult'), findsOneWidget);
    expect(find.text('High priority'), findsOneWidget);
    expect(find.text('4 h / week'), findsOneWidget);
  });
}
