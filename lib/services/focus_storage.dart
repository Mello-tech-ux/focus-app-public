import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/availability_window.dart';
import '../models/study_module.dart';
import '../models/study_plan.dart';
import '../models/study_preferences.dart';
import '../models/study_session.dart';

class FocusStorage {
  FocusStorage._();

  static const String _modulesKey = 'focus_modules';
  static const String _availabilityKey = 'focus_availability';
  static const String _preferencesKey = 'focus_preferences';
  static const String _studyPlansKey = 'focus_study_plans';
  static const String _studySessionsKey = 'focus_study_sessions';
  static const String _completedSessionsKey =
      'focus_completed_sessions';

  // ------------------------------------------------------------
  // MODULES
  // ------------------------------------------------------------

  static Future<void> saveModules(
    List<StudyModule> modules,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final data = modules
        .map(
          (module) => {
            'id': module.id,
            'name': module.name,
            'code': module.code,
            'difficulty': module.difficulty.name,
            'priority': module.priority.name,
            'weeklyStudyTargetHours':
                module.weeklyStudyTargetHours,
            'color': module.color.toARGB32(),
          },
        )
        .toList();

    await preferences.setString(
      _modulesKey,
      jsonEncode(data),
    );
  }

  static Future<List<StudyModule>> loadModules() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_modulesKey);

    if (saved == null || saved.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => StudyModule(
              id: item['id'] as String,
              name: item['name'] as String,
              code: item['code'] as String?,
              difficulty: ModuleDifficulty.values.firstWhere(
                (value) => value.name == item['difficulty'],
                orElse: () => ModuleDifficulty.moderate,
              ),
              priority: ModulePriority.values.firstWhere(
                (value) => value.name == item['priority'],
                orElse: () => ModulePriority.normal,
              ),
              weeklyStudyTargetHours:
                  (item['weeklyStudyTargetHours'] as num?)
                      ?.toDouble(),
              color: Color(
                (item['color'] as num?)?.toInt() ??
                    Colors.indigo.toARGB32(),
              ),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // AVAILABILITY
  // ------------------------------------------------------------

  static Future<void> saveAvailability(
    List<AvailabilityWindow> windows,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final data = windows
        .map(
          (window) => {
            'id': window.id,
            'day': window.day.name,
            'startMinute':
                window.startTime.minutesSinceMidnight,
            'endMinute':
                window.endTime.minutesSinceMidnight,
          },
        )
        .toList();

    await preferences.setString(
      _availabilityKey,
      jsonEncode(data),
    );
  }

  static Future<List<AvailabilityWindow>>
      loadAvailability() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_availabilityKey);

    if (saved == null || saved.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => AvailabilityWindow(
              id: item['id'] as String,
              day: StudyDay.values.firstWhere(
                (value) => value.name == item['day'],
                orElse: () => StudyDay.monday,
              ),
              startTime: StudyTime(
                (item['startMinute'] as num).toInt(),
              ),
              endTime: StudyTime(
                (item['endMinute'] as num).toInt(),
              ),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // STUDY PREFERENCES
  // ------------------------------------------------------------

  static Future<void> savePreferences(
    StudyPreferences preferences,
  ) async {
    final storage =
        await SharedPreferences.getInstance();

    final data = {
      'preferredStudyPeriod':
          preferences.preferredStudyPeriod.name,
      'preferredSessionMinutes':
          preferences.preferredSessionMinutes,
      'preferredBreakMinutes':
          preferences.preferredBreakMinutes,
      'maximumDailyStudyMinutes':
          preferences.maximumDailyStudyMinutes,
      'restDays':
          preferences.restDays.map((day) => day.name).toList(),
    };

    await storage.setString(
      _preferencesKey,
      jsonEncode(data),
    );
  }

  static Future<StudyPreferences> loadPreferences() async {
    final storage =
        await SharedPreferences.getInstance();

    final saved = storage.getString(_preferencesKey);

    if (saved == null || saved.isEmpty) {
      return const StudyPreferences();
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is! Map) {
        return const StudyPreferences();
      }

      final restDaysData = decoded['restDays'];

      final restDays = <StudyDay>{};

      if (restDaysData is List) {
        for (final day in restDaysData) {
          if (day is String) {
            final matchingDay = StudyDay.values.where(
              (value) => value.name == day,
            );

            if (matchingDay.isNotEmpty) {
              restDays.add(matchingDay.first);
            }
          }
        }
      }

      return StudyPreferences(
        preferredStudyPeriod:
            PreferredStudyPeriod.values.firstWhere(
          (value) =>
              value.name ==
              decoded['preferredStudyPeriod'],
          orElse: () =>
              PreferredStudyPeriod.noPreference,
        ),
        preferredSessionMinutes:
            (decoded['preferredSessionMinutes'] as num?)
                    ?.toInt() ??
                45,
        preferredBreakMinutes:
            (decoded['preferredBreakMinutes'] as num?)
                    ?.toInt() ??
                10,
        maximumDailyStudyMinutes:
            (decoded['maximumDailyStudyMinutes'] as num?)
                ?.toInt(),
        restDays: restDays,
      );
    } catch (_) {
      return const StudyPreferences();
    }
  }

  // ------------------------------------------------------------
  // STUDY PLANS
  // ------------------------------------------------------------

  static Future<void> saveStudyPlans(
    List<StudyPlan> plans,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final data = plans
        .map(
          (plan) => {
            'moduleId': plan.moduleId,
            'mode': plan.mode.name,
            'mondayMinutes': plan.mondayMinutes,
            'tuesdayMinutes': plan.tuesdayMinutes,
            'wednesdayMinutes': plan.wednesdayMinutes,
            'thursdayMinutes': plan.thursdayMinutes,
            'fridayMinutes': plan.fridayMinutes,
            'saturdayMinutes': plan.saturdayMinutes,
            'sundayMinutes': plan.sundayMinutes,
          },
        )
        .toList();

    await preferences.setString(
      _studyPlansKey,
      jsonEncode(data),
    );
  }

  static Future<List<StudyPlan>> loadStudyPlans() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_studyPlansKey);

    if (saved == null || saved.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => StudyPlan(
              moduleId: item['moduleId'] as String,
              mode: StudyPlanMode.values.firstWhere(
                (value) => value.name == item['mode'],
                orElse: () => StudyPlanMode.automatic,
              ),
              mondayMinutes:
                  (item['mondayMinutes'] as num?)?.toInt() ?? 0,
              tuesdayMinutes:
                  (item['tuesdayMinutes'] as num?)?.toInt() ?? 0,
              wednesdayMinutes:
                  (item['wednesdayMinutes'] as num?)?.toInt() ?? 0,
              thursdayMinutes:
                  (item['thursdayMinutes'] as num?)?.toInt() ?? 0,
              fridayMinutes:
                  (item['fridayMinutes'] as num?)?.toInt() ?? 0,
              saturdayMinutes:
                  (item['saturdayMinutes'] as num?)?.toInt() ?? 0,
              sundayMinutes:
                  (item['sundayMinutes'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // TIMETABLE / STUDY SESSIONS
  // ------------------------------------------------------------

  static Future<void> saveStudySessions(
    List<StudySession> sessions,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final data = sessions
        .map(
          (session) => {
            'id': session.id,
            'moduleId': session.moduleId,
            'day': session.day.name,
            'startMinute': session.startMinute,
            'durationMinutes':
                session.durationMinutes,
          },
        )
        .toList();

    await preferences.setString(
      _studySessionsKey,
      jsonEncode(data),
    );
  }

  static Future<List<StudySession>>
      loadStudySessions() async {
    final preferences = await SharedPreferences.getInstance();
    final saved =
        preferences.getString(_studySessionsKey);

    if (saved == null || saved.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => StudySession(
              id: item['id'] as String,
              moduleId: item['moduleId'] as String,
              day: StudyDay.values.firstWhere(
                (value) => value.name == item['day'],
                orElse: () => StudyDay.monday,
              ),
              startMinute:
                  (item['startMinute'] as num).toInt(),
              durationMinutes:
                  (item['durationMinutes'] as num).toInt(),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------
  // COMPLETED SESSIONS
  // ------------------------------------------------------------

  static Future<void> saveCompletedSessions(
    Set<String> completedIds,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setStringList(
      _completedSessionsKey,
      completedIds.toList(),
    );
  }

  static Future<Set<String>>
      loadCompletedSessions() async {
    final preferences =
        await SharedPreferences.getInstance();

    final saved =
        preferences.getStringList(_completedSessionsKey);

    if (saved == null) {
      return <String>{};
    }

    return saved.toSet();
  }
}