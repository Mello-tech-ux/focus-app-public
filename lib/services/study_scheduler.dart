import '../models/availability_window.dart';
import '../models/study_module.dart';
import '../models/study_plan.dart';
import '../models/study_preferences.dart';
import '../models/study_session.dart';

class StudyScheduler {
  const StudyScheduler();

  List<StudySession> generate({
    required List<StudyModule> modules,
    required List<AvailabilityWindow> availability,
    required StudyPreferences preferences,
    required List<StudyPlan> plans,
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

    final weeklyRemainingMinutes = <String, int>{
      for (final module in targetModules)
        module.id:
            (module.weeklyStudyTargetHours! * 60).round(),
    };

    final dailyRemainingMinutes =
        <String, Map<StudyDay, int>>{};

    for (final module in targetModules) {
      final plan = _planForModule(module, plans);

      if (plan == null ||
          plan.mode == StudyPlanMode.automatic) {
        dailyRemainingMinutes[module.id] = {
          for (final day in StudyDay.values) day: 0,
        };
      } else {
        dailyRemainingMinutes[module.id] = {
          StudyDay.monday: plan.mondayMinutes,
          StudyDay.tuesday: plan.tuesdayMinutes,
          StudyDay.wednesday: plan.wednesdayMinutes,
          StudyDay.thursday: plan.thursdayMinutes,
          StudyDay.friday: plan.fridayMinutes,
          StudyDay.saturday: plan.saturdayMinutes,
          StudyDay.sunday: plan.sundayMinutes,
        };
      }
    }

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

    while (_hasRemainingMinutes(
      weeklyRemainingMinutes,
      dailyRemainingMinutes,
      targetModules,
    )) {
      final candidates = <_ScheduleCandidate>[];

      for (final module in targetModules) {
        final weeklyRemaining =
            weeklyRemainingMinutes[module.id]!;

        if (weeklyRemaining <= 0) {
          continue;
        }

        for (final window in availability) {
          final day = window.day;

          if (preferences.restDays.contains(day)) {
            continue;
          }

          final dailyLimit =
              preferences.maximumDailyStudyMinutes;

          if (dailyLimit != null &&
              dailyUsedMinutes[day]! >= dailyLimit) {
            continue;
          }

          final plan = _planForModule(module, plans);

          final plannedForDay =
              dailyRemainingMinutes[module.id]![day]!;

          // Automatic mode does not have a fixed daily allocation.
          final hasAutomaticDistribution =
              plan == null ||
                  plan.mode == StudyPlanMode.automatic;

          if (!hasAutomaticDistribution &&
              plannedForDay <= 0) {
            continue;
          }

          final slot = _findNextSlot(
            sessions: sessions,
            window: window,
            breakMinutes: preferences.preferredBreakMinutes,
          );

          if (slot == null) {
            continue;
          }

          final duration = _calculateDuration(
            remainingMinutes: weeklyRemaining,
            plannedForDay: hasAutomaticDistribution
                ? null
                : plannedForDay,
            availableMinutes: slot.availableMinutes,
            dailyUsedMinutes: dailyUsedMinutes[day]!,
            preferences: preferences,
          );

          if (duration <= 0) {
            continue;
          }

          final score = _candidateScore(
            module: module,
            day: day,
            startMinute: slot.startMinute,
            activeDays: activeDays,
            sessions: sessions,
            preferences: preferences,
            plannedForDay:
                hasAutomaticDistribution ? null : plannedForDay,
          );

          candidates.add(
            _ScheduleCandidate(
              module: module,
              window: window,
              startMinute: slot.startMinute,
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
      final selectedDay = selected.window.day;

      final session = StudySession(
        id: '${selected.module.id}_${sessions.length}',
        moduleId: selected.module.id,
        day: selectedDay,
        startMinute: selected.startMinute,
        durationMinutes: selected.durationMinutes,
      );

      sessions.add(session);

      weeklyRemainingMinutes[selected.module.id] =
          weeklyRemainingMinutes[selected.module.id]! -
              selected.durationMinutes;

      final selectedPlan =
          _planForModule(selected.module, plans);

      final usesDailyPlan =
          selectedPlan != null &&
          selectedPlan.mode != StudyPlanMode.automatic;

      if (usesDailyPlan) {
        dailyRemainingMinutes[selected.module.id]![selectedDay] =
            (dailyRemainingMinutes[selected.module.id]![selectedDay]! -
                    selected.durationMinutes)
                .clamp(0, 24 * 60);
      }

      dailyUsedMinutes[selectedDay] =
          dailyUsedMinutes[selectedDay]! +
              selected.durationMinutes;
    }

    sessions.sort(_compareSessions);

    return sessions;
  }

  // ---------------------------------------------------------------------------
  // STUDY PLAN
  // ---------------------------------------------------------------------------

  StudyPlan? _planForModule(
    StudyModule module,
    List<StudyPlan> plans,
  ) {
    for (final plan in plans) {
      if (plan.moduleId == module.id) {
        return plan;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // REMAINING TIME
  // ---------------------------------------------------------------------------

  bool _hasRemainingMinutes(
    Map<String, int> weeklyRemainingMinutes,
    Map<String, Map<StudyDay, int>> dailyRemainingMinutes,
    List<StudyModule> modules,
  ) {
    for (final module in modules) {
      final weeklyRemaining =
          weeklyRemainingMinutes[module.id] ?? 0;

      if (weeklyRemaining <= 0) {
        continue;
      }

      final dailyPlan =
          dailyRemainingMinutes[module.id];

      if (dailyPlan == null) {
        return true;
      }

      final plan = dailyPlan.values.fold<int>(
        0,
        (total, minutes) => total + minutes,
      );

      // If there is a daily plan, only its remaining
      // allocation can be scheduled.
      if (plan > 0) {
        return true;
      }

      // Automatic mode uses the weekly target directly.
      return _hasAutomaticModule(
        module.id,
        dailyRemainingMinutes,
      );
    }

    return false;
  }

  bool _hasAutomaticModule(
    String moduleId,
    Map<String, Map<StudyDay, int>> dailyRemainingMinutes,
  ) {
    final dailyPlan = dailyRemainingMinutes[moduleId];

    if (dailyPlan == null) {
      return true;
    }

    return dailyPlan.values.every(
      (minutes) => minutes == 0,
    );
  }

  // ---------------------------------------------------------------------------
  // DURATION
  // ---------------------------------------------------------------------------

  int _calculateDuration({
    required int remainingMinutes,
    required int? plannedForDay,
    required int availableMinutes,
    required int dailyUsedMinutes,
    required StudyPreferences preferences,
  }) {
    var duration = preferences.preferredSessionMinutes;

    if (duration <= 0) {
      duration = 45;
    }

    // Never exceed the module's remaining weekly target.
    if (duration > remainingMinutes) {
      duration = remainingMinutes;
    }

    // Manual / Assisted plans have a daily allocation.
    if (plannedForDay != null &&
        duration > plannedForDay) {
      duration = plannedForDay;
    }

    // Never exceed the available timetable slot.
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

  // ---------------------------------------------------------------------------
  // CANDIDATE SCORING
  // ---------------------------------------------------------------------------

  double _candidateScore({
    required StudyModule module,
    required StudyDay day,
    required int startMinute,
    required List<StudyDay> activeDays,
    required List<StudySession> sessions,
    required StudyPreferences preferences,
    required int? plannedForDay,
  }) {
    double score = 0;

    // Higher-priority modules should be scheduled first.
    score += _priorityValue(module.priority) * 30;

    // More difficult modules receive an additional boost.
    score += _difficultyValue(module.difficulty) * 8;

    // Respect morning / afternoon / evening preference.
    score +=
        _periodPreferenceScore(
          startMinute,
          preferences.preferredStudyPeriod,
        ) *
        15;

    // If a study plan specifically allocated time to this day,
    // strongly prefer using that allocation.
    if (plannedForDay != null && plannedForDay > 0) {
      score += 50;
    }

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
        .where(
          (session) => session.day == day,
        )
        .toList();

    final dayMinutes = daySessions.fold<int>(
      0,
      (total, session) =>
          total + session.durationMinutes,
    );

    // Prefer days with less study already scheduled.
    if (activeDays.length > 1) {
      score +=
          (100 - dayMinutes).clamp(0, 100) * 0.15;
    }

    return score;
  }

  // ---------------------------------------------------------------------------
  // PREFERRED STUDY PERIOD
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // PRIORITY / DIFFICULTY
  // ---------------------------------------------------------------------------

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

  int _difficultyValue(
    ModuleDifficulty difficulty,
  ) {
    switch (difficulty) {
      case ModuleDifficulty.easy:
        return 1;

      case ModuleDifficulty.moderate:
        return 2;

      case ModuleDifficulty.difficult:
        return 3;
    }
  }

  // ---------------------------------------------------------------------------
  // FIND NEXT AVAILABLE SLOT
  // ---------------------------------------------------------------------------

  _ScheduleSlot? _findNextSlot({
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
        (a, b) =>
            a.startMinute.compareTo(b.startMinute),
      );

    for (final session in sessionsInWindow) {
      // Existing session is completely before our
      // current position.
      if (session.endMinute <= candidate) {
        continue;
      }

      // There is a free gap before the existing session.
      if (session.startMinute > candidate) {
        final gap = session.startMinute - candidate;

        if (gap > 0) {
          return _ScheduleSlot(
            startMinute: candidate,
            availableMinutes: gap,
          );
        }
      }

      // Move past the existing session and include
      // the preferred break.
      candidate =
          session.endMinute + breakMinutes;

      if (candidate >= windowEnd) {
        return null;
      }
    }

    final remaining =
        windowEnd - candidate;

    if (remaining <= 0) {
      return null;
    }

    return _ScheduleSlot(
      startMinute: candidate,
      availableMinutes: remaining,
    );
  }

  // ---------------------------------------------------------------------------
  // SORTING
  // ---------------------------------------------------------------------------

  int _compareSessions(
    StudySession a,
    StudySession b,
  ) {
    final dayComparison =
        _dayValue(a.day).compareTo(
          _dayValue(b.day),
        );

    if (dayComparison != 0) {
      return dayComparison;
    }

    return a.startMinute.compareTo(
      b.startMinute,
    );
  }

  int _dayValue(StudyDay day) {
    return StudyDay.values.indexOf(day);
  }
}

// -----------------------------------------------------------------------------
// INTERNAL CLASSES
// -----------------------------------------------------------------------------

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

class _ScheduleSlot {
  const _ScheduleSlot({
    required this.startMinute,
    required this.availableMinutes,
  });

  final int startMinute;
  final int availableMinutes;
}