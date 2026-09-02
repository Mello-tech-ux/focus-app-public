enum StudyDay { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension StudyDayLabel on StudyDay {
  String get label => switch (this) {
        StudyDay.monday => 'Monday',
        StudyDay.tuesday => 'Tuesday',
        StudyDay.wednesday => 'Wednesday',
        StudyDay.thursday => 'Thursday',
        StudyDay.friday => 'Friday',
        StudyDay.saturday => 'Saturday',
        StudyDay.sunday => 'Sunday',
      };
}

/// An exact time of day, independent from its UI representation.
class StudyTime implements Comparable<StudyTime> {
  StudyTime(this.minutesSinceMidnight) {
    if (minutesSinceMidnight < 0 || minutesSinceMidnight >= 24 * 60) {
      throw ArgumentError.value(
        minutesSinceMidnight,
        'minutesSinceMidnight',
        'must be between 0 and 1439',
      );
    }
  }

  final int minutesSinceMidnight;

  int get hour => minutesSinceMidnight ~/ 60;
  int get minute => minutesSinceMidnight % 60;

  @override
  int compareTo(StudyTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);
}

class AvailabilityWindow {
  AvailabilityWindow({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  }) {
    if (startTime.compareTo(endTime) >= 0) {
      throw ArgumentError('End time must be after start time.');
    }
  }

  final String id;
  final StudyDay day;
  final StudyTime startTime;
  final StudyTime endTime;

  bool overlaps(AvailabilityWindow other) {
    if (day != other.day) return false;
    return startTime.compareTo(other.endTime) < 0 &&
        endTime.compareTo(other.startTime) > 0;
  }

  AvailabilityWindow copyWith({
    StudyDay? day,
    StudyTime? startTime,
    StudyTime? endTime,
  }) {
    return AvailabilityWindow(
      id: id,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

bool hasOverlappingAvailability(
  Iterable<AvailabilityWindow> windows,
  AvailabilityWindow candidate,
) {
  return windows.any((window) => window.id != candidate.id && window.overlaps(candidate));
}
