

enum StudyPlanMode {
  automatic,
  assisted,
  manual,
}

class StudyPlan {
  const StudyPlan({
    required this.moduleId,
    required this.mode,
    this.mondayMinutes = 0,
    this.tuesdayMinutes = 0,
    this.wednesdayMinutes = 0,
    this.thursdayMinutes = 0,
    this.fridayMinutes = 0,
    this.saturdayMinutes = 0,
    this.sundayMinutes = 0,
  })  : assert(mondayMinutes >= 0),
        assert(tuesdayMinutes >= 0),
        assert(wednesdayMinutes >= 0),
        assert(thursdayMinutes >= 0),
        assert(fridayMinutes >= 0),
        assert(saturdayMinutes >= 0),
        assert(sundayMinutes >= 0);

  final String moduleId;
  final StudyPlanMode mode;

  final int mondayMinutes;
  final int tuesdayMinutes;
  final int wednesdayMinutes;
  final int thursdayMinutes;
  final int fridayMinutes;
  final int saturdayMinutes;
  final int sundayMinutes;

  int get totalAllocatedMinutes =>
      mondayMinutes +
      tuesdayMinutes +
      wednesdayMinutes +
      thursdayMinutes +
      fridayMinutes +
      saturdayMinutes +
      sundayMinutes;

  int minutesForDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return mondayMinutes;
      case DateTime.tuesday:
        return tuesdayMinutes;
      case DateTime.wednesday:
        return wednesdayMinutes;
      case DateTime.thursday:
        return thursdayMinutes;
      case DateTime.friday:
        return fridayMinutes;
      case DateTime.saturday:
        return saturdayMinutes;
      case DateTime.sunday:
        return sundayMinutes;
      default:
        throw ArgumentError('Weekday must be between 1 and 7.');
    }
  }
}
