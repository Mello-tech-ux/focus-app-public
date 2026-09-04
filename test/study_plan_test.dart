import 'package:flutter_test/flutter_test.dart';

import 'package:focus/models/study_plan.dart';

void main() {
  test('calculates total allocated study time', () {
    const plan = StudyPlan(
      moduleId: 'mat101',
      mode: StudyPlanMode.assisted,
      mondayMinutes: 120,
      tuesdayMinutes: 60,
      thursdayMinutes: 30,
      saturdayMinutes: 30,
    );

    expect(plan.totalAllocatedMinutes, 240);
  });

  test('returns the allocated minutes for a specific day', () {
    const plan = StudyPlan(
      moduleId: 'mat101',
      mode: StudyPlanMode.manual,
      mondayMinutes: 120,
      tuesdayMinutes: 60,
      thursdayMinutes: 30,
    );

    expect(plan.minutesForDay(DateTime.monday), 120);
    expect(plan.minutesForDay(DateTime.tuesday), 60);
    expect(plan.minutesForDay(DateTime.thursday), 30);
    expect(plan.minutesForDay(DateTime.friday), 0);
  });

  test('supports automatic planning with no manual allocation', () {
    const plan = StudyPlan(
      moduleId: 'mat101',
      mode: StudyPlanMode.automatic,
    );

    expect(plan.totalAllocatedMinutes, 0);
  });

  test('rejects an invalid weekday', () {
    const plan = StudyPlan(
      moduleId: 'mat101',
      mode: StudyPlanMode.manual,
    );

    expect(
      () => plan.minutesForDay(8),
      throwsArgumentError,
    );
  });
}
