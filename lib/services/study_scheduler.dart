import '../models/availability_window.dart';
import '../models/study_module.dart';
import '../models/study_preferences.dart';
import '../models/study_session.dart';

class StudyScheduler {
  const StudyScheduler();

  List<StudySession> generate({
    required List<StudyModule> modules,
    required List<AvailabilityWindow> availability,
    required StudyPreferences preferences,
  }) {
    if (modules.isEmpty || availability.isEmpty) {
      return [];
    }

    final targetModules = modules
        .where((module) => module.weeklyStudyTargetHours != null)
        .toList();

    if (targetModules.isEmpty) {
      return [];
    }

    final sessions = <StudySession>[];

    final remainingMinutes = <String, int>{
      for (final module in targetModules)
        module.id:
            (module.weeklyStudyTargetHours! * 60).round(),
    };

    final dailyUsedMinutes = <StudyDay, int>{
      for (final day in StudyDay.values) day: 0,
    };

    final activeDays = availability
        .map((window) => window.day)
        .where(
          (day) => !preferences.restDays.contains(day),
        )
        .toSet()
        .toList();

    if (activeDays.isEmpty) {
      return [];
    }

    while (_hasRemainingMinutes(remainingMinutes)) {
      final candidates = <_ScheduleCandidate>[];

      for (final module in targetModules) {
        final moduleRemaining = remainingMinutes[module.id]!;

        if (moduleRemaining <= 0) {
          continue;
        }

        for (final window in availability) {
          if (preferences.restDays.contains(window.day)) {
            continue;
          }

          final dailyLimit =
              preferences.maximumDailyStudyMinutes;

          if (dailyLimit != null &&
              dailyUsedMinutes[window.day]! >= dailyLimit) {
            continue;
          }

          final startMinute = _findNextStartMinute(
            sessions: sessions,
            window: window,
            breakMinutes: preferences.preferredBreakMinutes,
          );

          if (startMinute == null) {
            continue;
          }

          final availableMinutes =
              window.endTime.minutesSinceMidnight -
                  startMinute;

          if (availableMinutes <= 0) {
            continue;
          }

          final duration = _calculateDuration(
            remainingMinutes: moduleRemaining,
            availableMinutes: availableMinutes,
            dailyUsedMinutes: dailyUsedMinutes[window.day]!,
            preferences: preferences,
          );

          if (duration <= 0) {
            continue;
          }

          final score = _candidateScore(
            module: module,
            day: window.day,
            startMinute: startMinute,
            activeDays: activeDays,
            sessions: sessions,
            preferences: preferences,
          );

          candidates.add(
            _ScheduleCandidate(
              module: module,
              window: window,
              startMinute: startMinute,
              durationMinutes: duration,
              score: score,
            ),
          );
        }
      }

      if (candidates.isEmpty) {
        break;
      }

      candidates.sort(
        (a, b) => b.score.compareTo(a.score),
      );

      final selected = candidates.first;

      final session = StudySession(
        id: '${selected.module.id}_${sessions.length}',
        moduleId: selected.module.id,
        day: selected.window.day,
        startMinute: selected.startMinute,
        durationMinutes: selected.durationMinutes,
      );

      sessions.add(session);

      remainingMinutes[selected.module.id] =
          remainingMinutes[selected.module.id]! -
              selected.durationMinutes;

      dailyUsedMinutes[selected.window.day] =
          dailyUsedMinutes[selected.window.day]! +
              selected.durationMinutes;
    }

    sessions.sort(_compareSessions);

    return sessions;
  }

  bool _hasRemainingMinutes(
    Map<String, int> remainingMinutes,
  ) {
    return remainingMinutes.values.any(
      (minutes) => minutes > 0,
    );
  }

  int _calculateDuration({
    required int remainingMinutes,
    required int availableMinutes,
    required int dailyUsedMinutes,
    required StudyPreferences preferences,
  }) {
    var duration = preferences.preferredSessionMinutes;

    if (duration <= 0) {
      duration = 45;
    }

    if (duration > remainingMinutes) {
      duration = remainingMinutes;
    }

    if (duration > availableMinutes) {
      duration = availableMinutes;
    }

    final dailyLimit =
        preferences.maximumDailyStudyMinutes;

    if (dailyLimit != null) {
      final remainingDailyMinutes =
          dailyLimit - dailyUsedMinutes;

      if (duration > remainingDailyMinutes) {
        duration = remainingDailyMinutes;
      }
    }

    return duration;
  }

  double _candidateScore({
    required StudyModule module,
    required StudyDay day,
    required int startMinute,
    required List<StudyDay> activeDays,
    required List<StudySession> sessions,
    required StudyPreferences preferences,
  }) {
    double score = 0;

    // Higher-priority modules should be scheduled first.
    score += _priorityValue(module.priority) * 30;

    // More difficult modules receive a smaller additional boost.
    score += _difficultyValue(module.difficulty) * 8;

    // Respect morning / afternoon / evening preference.
    score +=
        _periodPreferenceScore(
          startMinute,
          preferences.preferredStudyPeriod,
        ) *
        15;

    final moduleSessions = sessions
        .where(
          (session) => session.moduleId == module.id,
        )
        .toList();

    if (moduleSessions.isEmpty) {
      // Give every module a chance to get its first session.
      score += 25;
    } else {
      final daysUsed = moduleSessions
          .map((session) => session.day)
          .toSet();

      // Prefer spreading a module across different days.
      if (!daysUsed.contains(day)) {
        score += 35;
      } else {
        score -= 10;
      }
    }

    final daySessions = sessions
        .where((session) => session.day == day)
        .toList();

    final dayMinutes = daySessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );

    // Prefer days with less study already scheduled.
    if (activeDays.length > 1) {
      score +=
          (100 - dayMinutes).clamp(0, 100) * 0.15;
    }

    return score;
  }

  double _periodPreferenceScore(
    int startMinute,
    PreferredStudyPeriod preference,
  ) {
    final hour = startMinute ~/ 60;

    switch (preference) {
      case PreferredStudyPeriod.morning:
        return hour < 12 ? 1 : 0;

      case PreferredStudyPeriod.afternoon:
        return hour >= 12 && hour < 17 ? 1 : 0;

      case PreferredStudyPeriod.evening:
        return hour >= 17 ? 1 : 0;

      case PreferredStudyPeriod.noPreference:
        return 0;
    }
  }

  int _priorityValue(ModulePriority priority) {
    switch (priority) {
      case ModulePriority.low:
        return 1;

      case ModulePriority.normal:
        return 2;

      case ModulePriority.high:
        return 3;
    }
  }

  int _difficultyValue(ModuleDifficulty difficulty) {
    switch (difficulty) {
      case ModuleDifficulty.easy:
        return 1;

      case ModuleDifficulty.moderate:
        return 2;

      case ModuleDifficulty.difficult:
        return 3;
    }
  }

  int? _findNextStartMinute({
    required List<StudySession> sessions,
    required AvailabilityWindow window,
    required int breakMinutes,
  }) {
    final windowStart =
        window.startTime.minutesSinceMidnight;

    final windowEnd =
        window.endTime.minutesSinceMidnight;

    var candidate = windowStart;

    final sessionsInWindow = sessions
        .where(
          (session) =>
              session.day == window.day &&
              session.startMinute < windowEnd &&
              session.endMinute > windowStart,
        )
        .toList()
      ..sort(
        (a, b) => a.startMinute.compareTo(b.startMinute),
      );

    for (final session in sessionsInWindow) {
      // The session is completely before our current position.
      if (session.endMinute <= candidate) {
        continue;
      }

      // There is a free gap before this existing session.
      if (session.startMinute > candidate) {
        return _validStartWithinWindow(
          candidate: candidate,
          windowStart: windowStart,
          windowEnd: windowEnd,
        );
      }

      // Move past the existing session and add the break.
      candidate = session.endMinute + breakMinutes;
    }

    return _validStartWithinWindow(
      candidate: candidate,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  int? _validStartWithinWindow({
    required int candidate,
    required int windowStart,
    required int windowEnd,
  }) {
    if (candidate < windowStart) {
      candidate = windowStart;
    }

    if (candidate >= windowEnd) {
      return null;
    }

    return candidate;
  }

  int _compareSessions(
    StudySession a,
    StudySession b,
  ) {
    final dayComparison =
        _dayValue(a.day).compareTo(_dayValue(b.day));

    if (dayComparison != 0) {
      return dayComparison;
    }

    return a.startMinute.compareTo(b.startMinute);
  }

  int _dayValue(StudyDay day) {
    return StudyDay.values.indexOf(day);
  }
}

class _ScheduleCandidate {
  const _ScheduleCandidate({
    required this.module,
    required this.window,
    required this.startMinute,
    required this.durationMinutes,
    required this.score,
  });

  final StudyModule module;
  final AvailabilityWindow window;
  final int startMinute;
  final int durationMinutes;
  final double score;
}