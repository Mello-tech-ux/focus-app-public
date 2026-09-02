import 'availability_window.dart';

enum PreferredStudyPeriod { morning, afternoon, evening, noPreference }

extension PreferredStudyPeriodLabel on PreferredStudyPeriod {
  String get label => switch (this) {
        PreferredStudyPeriod.morning => 'Morning',
        PreferredStudyPeriod.afternoon => 'Afternoon',
        PreferredStudyPeriod.evening => 'Evening',
        PreferredStudyPeriod.noPreference => 'No preference',
      };
}

/// Soft guidance for a future scheduler; it never changes hard availability.
class StudyPreferences {
  const StudyPreferences({
    this.preferredStudyPeriod = PreferredStudyPeriod.noPreference,
    this.preferredSessionMinutes = 45,
    this.preferredBreakMinutes = 10,
    this.maximumDailyStudyMinutes,
    this.restDays = const {},
  });

  final PreferredStudyPeriod preferredStudyPeriod;
  final int preferredSessionMinutes;
  final int preferredBreakMinutes;
  final int? maximumDailyStudyMinutes;
  final Set<StudyDay> restDays;

  StudyPreferences copyWith({
    PreferredStudyPeriod? preferredStudyPeriod,
    int? preferredSessionMinutes,
    int? preferredBreakMinutes,
    int? maximumDailyStudyMinutes,
    bool clearMaximumDailyStudyTime = false,
    Set<StudyDay>? restDays,
  }) {
    return StudyPreferences(
      preferredStudyPeriod: preferredStudyPeriod ?? this.preferredStudyPeriod,
      preferredSessionMinutes: preferredSessionMinutes ?? this.preferredSessionMinutes,
      preferredBreakMinutes: preferredBreakMinutes ?? this.preferredBreakMinutes,
      maximumDailyStudyMinutes: clearMaximumDailyStudyTime
          ? null
          : maximumDailyStudyMinutes ?? this.maximumDailyStudyMinutes,
      restDays: restDays ?? this.restDays,
    );
  }
}
