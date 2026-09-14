import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/availability_window.dart';
import 'models/study_module.dart';
import 'models/study_plan.dart';
import 'models/study_preferences.dart';
import 'models/study_session.dart';
import 'screens/availability_screen.dart';
import 'screens/modules_screen.dart';
import 'screens/study_plan_screen.dart';
import 'screens/study_preferences_screen.dart';
import 'screens/study_session_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/study_scheduler.dart';

void main() {
  runApp(const FocusApp());
}

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FOCUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315E51),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF7),
        useMaterial3: true,
      ),
      home: const AppEntryScreen(),
    );
  }
}

/// Decides whether the user should see the welcome screen
/// or go directly back into their saved FOCUS workspace.
class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _loading = true;
  bool _hasStarted = false;

  static const String _startedKey = 'focus_has_started';

  @override
  void initState() {
    super.initState();
    _loadEntryState();
  }

  Future<void> _loadEntryState() async {
    final preferences = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasStarted = preferences.getBool(_startedKey) ?? false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasStarted) {
      return const FocusHomeScreen();
    }

    return const WelcomeScreen();
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(
      'focus_has_started',
      true,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const FocusHomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.track_changes_rounded,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'FOCUS',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Focused Organization for Consistent '
                  'Undergraduate Study',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _start(context),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FocusHomeScreen extends StatefulWidget {
  const FocusHomeScreen({super.key});

  @override
  State<FocusHomeScreen> createState() => _FocusHomeScreenState();
}

class _FocusHomeScreenState extends State<FocusHomeScreen> {
  static const String _modulesKey = 'focus_modules';
  static const String _availabilityKey = 'focus_availability';
  static const String _preferencesKey = 'focus_preferences';
  static const String _plansKey = 'focus_study_plans';
  static const String _sessionsKey = 'focus_study_sessions';
  static const String _sessionProgressKey = 'focus_session_progress';
  static const String _startedKey = 'focus_has_started';

  List<StudyModule> _modules = [];
  List<AvailabilityWindow> _availability = [];
  StudyPreferences _preferences = const StudyPreferences();
  List<StudyPlan> _studyPlans = [];
  List<StudySession> _studySessions = [];

  final Set<String> _completedSessionIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> _loadAllData() async {
    final preferences = await SharedPreferences.getInstance();

    final modules = _decodeList(
      preferences.getString(_modulesKey),
    );

    final availability = _decodeList(
      preferences.getString(_availabilityKey),
    );

    final plans = _decodeList(
      preferences.getString(_plansKey),
    );

    final sessions = _decodeList(
      preferences.getString(_sessionsKey),
    );

    final savedPreferences =
        preferences.getString(_preferencesKey);

    final loadedModules = <StudyModule>[];
    for (final item in modules) {
      final module = _moduleFromMap(item);
      if (module != null) {
        loadedModules.add(module);
      }
    }

    final loadedAvailability = <AvailabilityWindow>[];
    for (final item in availability) {
      final window = _availabilityFromMap(item);
      if (window != null) {
        loadedAvailability.add(window);
      }
    }

    final loadedPlans = <StudyPlan>[];
    for (final item in plans) {
      final plan = _studyPlanFromMap(item);
      if (plan != null) {
        loadedPlans.add(plan);
      }
    }

    final loadedSessions = <StudySession>[];
    for (final item in sessions) {
      final session = _studySessionFromMap(item);
      if (session != null) {
        loadedSessions.add(session);
      }
    }

    final loadedStudyPreferences =
        savedPreferences == null
            ? const StudyPreferences()
            : _studyPreferencesFromMap(
                  _decodeMap(savedPreferences),
                ) ??
                const StudyPreferences();

    final savedProgress = _decodeMap(
      preferences.getString(_sessionProgressKey),
    );

    final completedIds = <String>{};

    for (final session in loadedSessions) {
      final saved = savedProgress[session.id];

      if (saved is Map<String, dynamic>) {
        if (saved['isComplete'] == true) {
          completedIds.add(session.id);
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _modules = loadedModules;
      _availability = loadedAvailability;
      _studyPlans = loadedPlans;
      _studySessions = loadedSessions;
      _preferences = loadedStudyPreferences;

      _completedSessionIds
        ..clear()
        ..addAll(completedIds);

      _isLoading = false;
    });

    await preferences.setBool(
      _startedKey,
      true,
    );
  }

  Future<void> _saveAllData() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _modulesKey,
      jsonEncode(
        _modules.map(_moduleToMap).toList(),
      ),
    );

    await preferences.setString(
      _availabilityKey,
      jsonEncode(
        _availability.map(_availabilityToMap).toList(),
      ),
    );

    await preferences.setString(
      _preferencesKey,
      jsonEncode(
        _studyPreferencesToMap(_preferences),
      ),
    );

    await preferences.setString(
      _plansKey,
      jsonEncode(
        _studyPlans.map(_studyPlanToMap).toList(),
      ),
    );

    await preferences.setString(
      _sessionsKey,
      jsonEncode(
        _studySessions.map(_studySessionToMap).toList(),
      ),
    );

    await preferences.setBool(
      _startedKey,
      true,
    );
  }

  List<Map<String, dynamic>> _decodeList(String? value) {
    if (value == null || value.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }
    } catch (_) {
      // Ignore corrupted data.
    }

    return [];
  }

  Map<String, dynamic> _decodeMap(String? value) {
    if (value == null || value.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupted data.
    }

    return {};
  }

  // ---------------------------------------------------------------------------
  // MODULE SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _moduleToMap(StudyModule module) {
    return {
      'id': module.id,
      'name': module.name,
      'code': module.code,
      'difficulty': module.difficulty.name,
      'priority': module.priority.name,
      'weeklyStudyTargetHours':
          module.weeklyStudyTargetHours,
      'color': module.color.toARGB32(),
    };
  }

  StudyModule? _moduleFromMap(
    Map<String, dynamic> map,
  ) {
    try {
      final difficulty = ModuleDifficulty.values.firstWhere(
        (value) => value.name == map['difficulty'],
        orElse: () => ModuleDifficulty.moderate,
      );

      final priority = ModulePriority.values.firstWhere(
        (value) => value.name == map['priority'],
        orElse: () => ModulePriority.normal,
      );

      final colorValue = map['color'];

      return StudyModule(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        difficulty: difficulty,
        priority: priority,
        weeklyStudyTargetHours:
            (map['weeklyStudyTargetHours'] as num?)
                ?.toDouble(),
        color: colorValue is int
            ? Color(colorValue)
            : const Color(0xFF315E51),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // AVAILABILITY SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _availabilityToMap(
    AvailabilityWindow window,
  ) {
    return {
      'id': window.id,
      'day': window.day.name,
      'startTime':
          window.startTime.minutesSinceMidnight,
      'endTime':
          window.endTime.minutesSinceMidnight,
    };
  }

  AvailabilityWindow? _availabilityFromMap(
    Map<String, dynamic> map,
  ) {
    try {
      final day = StudyDay.values.firstWhere(
        (value) => value.name == map['day'],
      );

      return AvailabilityWindow(
        id: map['id'] as String,
        day: day,
        startTime: StudyTime(
          map['startTime'] as int,
        ),
        endTime: StudyTime(
          map['endTime'] as int,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // STUDY PREFERENCES SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _studyPreferencesToMap(
    StudyPreferences preferences,
  ) {
    return {
      'preferredStudyPeriod':
          preferences.preferredStudyPeriod.name,
      'preferredSessionMinutes':
          preferences.preferredSessionMinutes,
      'preferredBreakMinutes':
          preferences.preferredBreakMinutes,
      'maximumDailyStudyMinutes':
          preferences.maximumDailyStudyMinutes,
      'restDays':
          preferences.restDays
              .map((day) => day.name)
              .toList(),
    };
  }

  StudyPreferences? _studyPreferencesFromMap(
    Map<String, dynamic> map,
  ) {
    try {
      final preferredPeriod =
          PreferredStudyPeriod.values.firstWhere(
        (value) =>
            value.name ==
            map['preferredStudyPeriod'],
        orElse: () =>
            PreferredStudyPeriod.noPreference,
      );

      final restDays = <StudyDay>{};

      final savedRestDays = map['restDays'];

      if (savedRestDays is List) {
        for (final value in savedRestDays) {
          if (value is String) {
            for (final day in StudyDay.values) {
              if (day.name == value) {
                restDays.add(day);
              }
            }
          }
        }
      }

      return StudyPreferences(
        preferredStudyPeriod:
            preferredPeriod,
        preferredSessionMinutes:
            map['preferredSessionMinutes']
                    as int? ??
                45,
        preferredBreakMinutes:
            map['preferredBreakMinutes']
                    as int? ??
                10,
        maximumDailyStudyMinutes:
            map['maximumDailyStudyMinutes']
                as int?,
        restDays: restDays,
      );
    } catch (_) {
      return const StudyPreferences();
    }
  }

  // ---------------------------------------------------------------------------
  // STUDY PLAN SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _studyPlanToMap(
    StudyPlan plan,
  ) {
    return {
      'moduleId': plan.moduleId,
      'mode': plan.mode.name,
      'mondayMinutes': plan.mondayMinutes,
      'tuesdayMinutes': plan.tuesdayMinutes,
      'wednesdayMinutes':
          plan.wednesdayMinutes,
      'thursdayMinutes':
          plan.thursdayMinutes,
      'fridayMinutes': plan.fridayMinutes,
      'saturdayMinutes':
          plan.saturdayMinutes,
      'sundayMinutes':
          plan.sundayMinutes,
    };
  }

  StudyPlan? _studyPlanFromMap(
    Map<String, dynamic> map,
  ) {
    try {
      final mode = StudyPlanMode.values.firstWhere(
        (value) => value.name == map['mode'],
        orElse: () =>
            StudyPlanMode.automatic,
      );

      return StudyPlan(
        moduleId: map['moduleId'] as String,
        mode: mode,
        mondayMinutes:
            map['mondayMinutes'] as int? ?? 0,
        tuesdayMinutes:
            map['tuesdayMinutes'] as int? ?? 0,
        wednesdayMinutes:
            map['wednesdayMinutes'] as int? ?? 0,
        thursdayMinutes:
            map['thursdayMinutes'] as int? ?? 0,
        fridayMinutes:
            map['fridayMinutes'] as int? ?? 0,
        saturdayMinutes:
            map['saturdayMinutes'] as int? ?? 0,
        sundayMinutes:
            map['sundayMinutes'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // STUDY SESSION SERIALIZATION
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _studySessionToMap(
    StudySession session,
  ) {
    return {
      'id': session.id,
      'moduleId': session.moduleId,
      'day': session.day.name,
      'startMinute': session.startMinute,
      'durationMinutes':
          session.durationMinutes,
    };
  }

  StudySession? _studySessionFromMap(
    Map<String, dynamic> map,
  ) {
    try {
      final day = StudyDay.values.firstWhere(
        (value) => value.name == map['day'],
      );

      return StudySession(
        id: map['id'] as String,
        moduleId: map['moduleId'] as String,
        day: day,
        startMinute:
            map['startMinute'] as int,
        durationMinutes:
            map['durationMinutes'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openModules() async {
    final modules =
        await Navigator.of(context).push<List<StudyModule>>(
      MaterialPageRoute<List<StudyModule>>(
        builder: (_) => ModulesScreen(
          initialModules: _modules,
        ),
      ),
    );

    if (modules != null && mounted) {
      setState(() {
        _modules = modules;
      });

      await _saveAllData();
    }
  }

  Future<void> _openAvailability() async {
    final windows =
        await Navigator.of(context)
            .push<List<AvailabilityWindow>>(
      MaterialPageRoute<List<AvailabilityWindow>>(
        builder: (_) => AvailabilityScreen(
          initialWindows: _availability,
        ),
      ),
    );

    if (windows != null && mounted) {
      setState(() {
        _availability
          ..clear()
          ..addAll(windows);
      });

      await _saveAllData();
    }
  }

  Future<void> _openPreferences() async {
    final preferences =
        await Navigator.of(context)
            .push<StudyPreferences>(
      MaterialPageRoute<StudyPreferences>(
        builder: (_) =>
            StudyPreferencesScreen(
          initialPreferences: _preferences,
        ),
      ),
    );

    if (preferences != null && mounted) {
      setState(() {
        _preferences = preferences;
      });

      await _saveAllData();
    }
  }

  Future<void> _openStudyPlan() async {
    final plans =
        await Navigator.of(context)
            .push<List<StudyPlan>>(
      MaterialPageRoute<List<StudyPlan>>(
        builder: (_) => StudyPlanScreen(
          modules: _modules,
          initialPlans: _studyPlans,
        ),
      ),
    );

    if (plans != null && mounted) {
      setState(() {
        _studyPlans = plans;
      });

      await _saveAllData();
    }
  }

  void _generateTimetable() {
    final modulesWithTargets = _modules
        .where(
          (module) =>
              module.weeklyStudyTargetHours !=
              null,
        )
        .toList();

    if (modulesWithTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add weekly study targets to your modules first.',
          ),
        ),
      );
      return;
    }

    if (_availability.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your availability first.',
          ),
        ),
      );
      return;
    }

    final scheduler =
        const StudyScheduler();

    final sessions = scheduler.generate(
      modules: _modules,
      availability: _availability,
      preferences: _preferences,
      plans: _studyPlans,
    );

    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'FOCUS could not find enough available study '
            'time for your targets.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _studySessions = sessions;
      _completedSessionIds.clear();
    });

    _saveAllData();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimetableScreen(
          modules: _modules,
          sessions: _studySessions,
        ),
      ),
    );
  }

  void _openTimetable() {
    if (_studySessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Generate your timetable first.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimetableScreen(
          modules: _modules,
          sessions: _studySessions,
        ),
      ),
    );
  }

  StudyModule? _moduleForSession(
    StudySession session,
  ) {
    for (final module in _modules) {
      if (module.id == session.moduleId) {
        return module;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // SESSION PROGRESS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>>
      _loadSessionProgress() async {
    final preferences =
        await SharedPreferences.getInstance();

    return _decodeMap(
      preferences.getString(
        _sessionProgressKey,
      ),
    );
  }

  int _studiedMinutesForSession(
    StudySession session,
    Map<String, dynamic> progress,
  ) {
    final saved = progress[session.id];

    if (saved is! Map<String, dynamic>) {
      return 0;
    }

    final remaining = saved['remainingSeconds'];

    if (remaining is! num) {
      return 0;
    }

    final totalSeconds =
        session.durationMinutes * 60;

    final studiedSeconds =
        (totalSeconds - remaining.toInt())
            .clamp(0, totalSeconds);

    return studiedSeconds ~/ 60;
  }

  Future<void> _startSession(
    StudySession session,
  ) async {
    final module =
        _moduleForSession(session);

    final completed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            StudySessionScreen(
          sessionId: session.id,
          moduleName:
              module?.name ??
                  'Unknown module',
          durationMinutes:
              session.durationMinutes,

          // FIXED:
          moduleId: session.moduleId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    final progress =
        await _loadSessionProgress();

    final saved =
        progress[session.id];

    final sessionIsComplete =
        saved is Map<String, dynamic> &&
        saved['isComplete'] == true;

    if (completed == true ||
        sessionIsComplete) {
      setState(() {
        _completedSessionIds
            .add(session.id);
      });

      await _saveAllData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Session completed. Stay mellow. 🔥',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HOME DATA
  // ---------------------------------------------------------------------------

  List<StudySession> _todaySessions() {
    final today =
        StudyDay.values[
            DateTime.now().weekday - 1];

    final sessions =
        _studySessions
            .where(
              (session) =>
                  session.day == today,
            )
            .toList();

    sessions.sort(
      (a, b) =>
          a.startMinute
              .compareTo(b.startMinute),
    );

    return sessions;
  }

  Future<StudySession?> _nextSession() async {
    if (_studySessions.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final todayIndex =
        now.weekday - 1;

    final currentMinute =
        now.hour * 60 + now.minute;

    final progress =
        await _loadSessionProgress();

    final upcoming =
        _studySessions.where((session) {
      final saved =
          progress[session.id];

      final completed =
          saved is Map<String, dynamic> &&
          saved['isComplete'] == true;

      if (completed) {
        return false;
      }

      final sessionDayIndex =
          StudyDay.values.indexOf(
        session.day,
      );

      if (sessionDayIndex >
          todayIndex) {
        return true;
      }

      if (sessionDayIndex ==
              todayIndex &&
          session.startMinute >=
              currentMinute) {
        return true;
      }

      return false;
    }).toList();

    if (upcoming.isEmpty) {
      return null;
    }

    upcoming.sort((a, b) {
      final dayComparison =
          StudyDay.values
              .indexOf(a.day)
              .compareTo(
                StudyDay.values
                    .indexOf(b.day),
              );

      if (dayComparison != 0) {
        return dayComparison;
      }

      return a.startMinute.compareTo(
        b.startMinute,
      );
    });

    return upcoming.first;
  }

  Future<_TodayProgress> _getTodayProgress() async {
    final progress = await _loadSessionProgress();
    final sessions = _todaySessions();

    var studiedMinutes = 0;
    var completedSessions = 0;
    var plannedMinutes = 0;

    for (final session in sessions) {
      plannedMinutes += session.durationMinutes;
      studiedMinutes += _studiedMinutesForSession(session, progress);

      final saved = progress[session.id];
      if (saved is Map<String, dynamic> &&
          saved['isComplete'] == true) {
        completedSessions++;
      }
    }

    return _TodayProgress(
      plannedMinutes: plannedMinutes,
      studiedMinutes: studiedMinutes,
      completedSessions: completedSessions,
      totalSessions: sessions.length,
    );
  }

  Widget _buildTodayOverview(BuildContext context) {
    return FutureBuilder<_TodayProgress>(
      future: _getTodayProgress(),
      builder: (context, snapshot) {
        final progress = snapshot.data ??
            const _TodayProgress(
              plannedMinutes: 0,
              studiedMinutes: 0,
              completedSessions: 0,
              totalSessions: 0,
            );

        final remainingMinutes =
            (progress.plannedMinutes - progress.studiedMinutes)
                .clamp(0, progress.plannedMinutes);

        final percentage = progress.plannedMinutes <= 0
            ? 0
            : ((progress.studiedMinutes / progress.plannedMinutes) * 100)
                .round()
                .clamp(0, 100);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Overview",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressStat(
                        context,
                        'Studied',
                        _formatMinutes(progress.studiedMinutes),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildProgressStat(
                        context,
                        'Remaining',
                        _formatMinutes(remainingMinutes),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildProgressStat(
                        context,
                        'Complete',
                        '$percentage%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${progress.completedSessions} of '
                  '${progress.totalSessions} '
                  '${progress.totalSessions == 1 ? 'session' : 'sessions'} '
                  'complete today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TODAY PROGRESS
  // ---------------------------------------------------------------------------

  String _formatMinutes(
    int minutes,
  ) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours > 0 &&
        remainder > 0) {
      return '${hours}h ${remainder}m';
    }

    if (hours > 0) {
      return '${hours}h';
    }

    return '${minutes}m';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<StudySession?>(
      future: _nextSession(),
      builder: (context, snapshot) {
        final todaySessions =
            _todaySessions();

        final nextSession =
            snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('FOCUS'),
          ),
          body: ListView(
            padding:
                const EdgeInsets.all(20),
            children: [
              Text(
                'Stay focused.',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Plan your week. Study consistently.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),
              const SizedBox(height: 24),

              if (todaySessions.isNotEmpty) ...[
                _buildTodayOverview(context),
                const SizedBox(height: 16),
              ],

              _buildTodaySection(
                context,
                todaySessions,
              ),

              if (nextSession != null) ...[
                const SizedBox(height: 16),
                _buildNextSessionSection(
                  context,
                  nextSession,
                ),
              ],

              if (_studySessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildWeeklySummary(context),
              ],

              const SizedBox(height: 24),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_awesome_rounded,
                  ),
                  title: const Text(
                    'Generate Timetable',
                  ),
                  subtitle: const Text(
                    'Let FOCUS build your weekly study schedule.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                  ),
                  onTap:
                      _generateTimetable,
                ),
              ),

              if (_studySessions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month_rounded,
                    ),
                    title: const Text(
                      'My Timetable',
                    ),
                    subtitle: Text(
                      '${_studySessions.length} scheduled '
                      '${_studySessions.length == 1 ? 'session' : 'sessions'}',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                    ),
                    onTap:
                        _openTimetable,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.menu_book_rounded,
                  ),
                  title: const Text(
                    'My Modules',
                  ),
                  subtitle: Text(
                    _modules.isEmpty
                        ? 'Add your university modules.'
                        : '${_modules.length} '
                              '${_modules.length == 1 ? 'module' : 'modules'}',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                  ),
                  onTap: _openModules,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.access_time_rounded,
                  ),
                  title: const Text(
                    'My Availability',
                  ),
                  subtitle: Text(
                    _availability.isEmpty
                        ? 'Tell FOCUS when you can study.'
                        : '${_availability.length} availability '
                              '${_availability.length == 1 ? 'window' : 'windows'}',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                  ),
                  onTap:
                      _openAvailability,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.tune_rounded,
                  ),
                  title: const Text(
                    'Study Preferences',
                  ),
                  subtitle: const Text(
                    'Choose how FOCUS should plan your study.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                  ),
                  onTap:
                      _openPreferences,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.event_note_rounded,
                  ),
                  title: const Text(
                    'Study Plan',
                  ),
                  subtitle: const Text(
                    'Control how your weekly study time is distributed.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                  ),
                  onTap:
                      _openStudyPlan,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TODAY
  // ---------------------------------------------------------------------------

  Widget _buildTodaySection(
    BuildContext context,
    List<StudySession> sessions,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Study",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .event_available_rounded,
                    color:
                        colors.primary,
                    size: 32,
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          _studySessions
                                  .isEmpty
                              ? 'No timetable yet'
                              : 'Nothing scheduled today',
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          _studySessions
                                  .isEmpty
                              ? 'Generate your timetable to see your study sessions here.'
                              : 'Enjoy the free time. Your next session will appear above.',
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...sessions.map(
            (session) =>
                _buildHomeSessionCard(
              context,
              session,
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HOME SESSION CARD
  // ---------------------------------------------------------------------------

  Widget _buildHomeSessionCard(
    BuildContext context,
    StudySession session,
  ) {
    final module =
        _moduleForSession(session);

    final moduleColor =
        module?.color ??
            Theme.of(context)
                .colorScheme
                .primary;

    return FutureBuilder<
        Map<String, dynamic>>(
      future: _loadSessionProgress(),
      builder:
          (context, snapshot) {
        final progress =
            snapshot.data ?? {};

        final studiedMinutes =
            _studiedMinutesForSession(
          session,
          progress,
        );

        final saved =
            progress[session.id];

        final isCompleted =
            saved is Map<String, dynamic> &&
            saved['isComplete'] == true;

        final isInProgress =
            studiedMinutes > 0 &&
            !isCompleted;

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 10,
          ),
          clipBehavior:
              Clip.antiAlias,
          child: InkWell(
            onTap: isCompleted
                ? null
                : () =>
                    _startSession(
                      session,
                    ),
            child: Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 82,
                    decoration:
                        BoxDecoration(
                      color:
                          moduleColor,
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          module?.name ??
                              'Unknown module',
                          style:
                              Theme.of(
                            context,
                          )
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          '${session.startLabel} – '
                          '${session.endLabel}',
                          style:
                              Theme.of(
                            context,
                          )
                                  .textTheme
                                  .bodyMedium,
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        if (isCompleted)
                          Text(
                            'Completed ✓',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(
                                        context,
                                      )
                                              .colorScheme
                                              .primary,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                          )
                        else if (isInProgress)
                          Text(
                            '$studiedMinutes min studied • '
                            '${session.durationMinutes - studiedMinutes} min left',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(
                                        context,
                                      )
                                              .colorScheme
                                              .primary,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                          )
                        else
                          Text(
                            '${session.durationMinutes} min',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  if (isCompleted)
                    Icon(
                      Icons
                          .check_circle_rounded,
                      color:
                          Theme.of(
                        context,
                      )
                              .colorScheme
                              .primary,
                      size: 30,
                    )
                  else
                    FilledButton(
                      onPressed: () =>
                          _startSession(
                        session,
                      ),
                      child: Text(
                        isInProgress
                            ? 'Resume'
                            : 'Start',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NEXT SESSION
  // ---------------------------------------------------------------------------

  Widget _buildNextSessionSection(
    BuildContext context,
    StudySession session,
  ) {
    final module =
        _moduleForSession(session);

    final colors =
        Theme.of(context).colorScheme;

    return Card(
      color:
          colors.primaryContainer,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upcoming_rounded,
                  color:
                      colors.onPrimaryContainer,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Up Next',
                  style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w800,
                            color: colors
                                .onPrimaryContainer,
                          ),
                ),
              ],
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              module?.name ??
                  'Unknown module',
              style:
                  Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                        color: colors
                            .onPrimaryContainer,
                      ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              '${session.day.label} • '
              '${session.startLabel} – '
              '${session.endLabel}',
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: colors
                            .onPrimaryContainer,
                      ),
            ),
            const SizedBox(
              height: 14,
            ),
            SizedBox(
              width:
                  double.infinity,
              child:
                  FilledButton.icon(
                onPressed: () =>
                    _startSession(
                  session,
                ),
                icon: const Icon(
                  Icons
                      .play_arrow_rounded,
                ),
                label: const Text(
                  'Start Session',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WEEKLY SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildWeeklySummary(
    BuildContext context,
  ) {
    return FutureBuilder<
        _WeeklyProgress>(
      future:
          _getWeeklyProgress(),
      builder:
          (context, snapshot) {
        final progress =
            snapshot.data ??
                const _WeeklyProgress(
                  plannedMinutes: 0,
                  studiedMinutes: 0,
                  completedSessions:
                      0,
                  totalSessions: 0,
                );

        final percentage =
            progress.plannedMinutes <=
                    0
                ? 0
                : ((progress.studiedMinutes /
                                progress
                                    .plannedMinutes) *
                            100)
                        .round()
                        .clamp(0, 100);

        final colors =
            Theme.of(context)
                .colorScheme;

        return Card(
          child: Padding(
            padding:
                const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        alignment:
                            Alignment
                                .center,
                        children: [
                          CircularProgressIndicator(
                            value:
                                percentage /
                                    100,
                            strokeWidth: 6,
                            backgroundColor:
                                colors
                                    .surfaceContainerHighest,
                          ),
                          Text(
                            '$percentage%',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'This Week',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            '${progress.completedSessions} of '
                            '${progress.totalSessions} '
                            '${progress.totalSessions == 1 ? 'session' : 'sessions'} '
                            'complete',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodyMedium,
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            '$percentage% of planned study time complete',
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 14,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          _buildProgressStat(
                        context,
                        'Studied',
                        _formatMinutes(
                          progress
                              .studiedMinutes,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          _buildProgressStat(
                        context,
                        'Planned',
                        _formatMinutes(
                          progress
                              .plannedMinutes,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          _buildProgressStat(
                        context,
                        'Remaining',
                        _formatMinutes(
                          (progress
                                      .plannedMinutes -
                                  progress
                                      .studiedMinutes)
                              .clamp(
                            0,
                            progress
                                .plannedMinutes,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStat(
    BuildContext context,
    String label,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style:
                Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style:
                Theme.of(context)
                    .textTheme
                    .bodySmall,
          ),
        ],
      ),
    );
  }

  Future<_WeeklyProgress>
      _getWeeklyProgress() async {
    final progress =
        await _loadSessionProgress();

    var studiedMinutes = 0;

    for (final session
        in _studySessions) {
      studiedMinutes +=
          _studiedMinutesForSession(
        session,
        progress,
      );
    }

    final completedSessions =
        _studySessions.where(
      (session) {
        final saved =
            progress[session.id];

        return saved
                is Map<String, dynamic> &&
            saved['isComplete'] ==
                true;
      },
    ).length;

    final plannedMinutes =
        _studySessions.fold<int>(
      0,
      (total, session) =>
          total +
          session.durationMinutes,
    );

    return _WeeklyProgress(
      plannedMinutes:
          plannedMinutes,
      studiedMinutes:
          studiedMinutes,
      completedSessions:
          completedSessions,
      totalSessions:
          _studySessions.length,
    );
  }
}

class _TodayProgress {
  const _TodayProgress({
    required this.plannedMinutes,
    required this.studiedMinutes,
    required this.completedSessions,
    required this.totalSessions,
  });

  final int plannedMinutes;
  final int studiedMinutes;
  final int completedSessions;
  final int totalSessions;
}

class _WeeklyProgress {
  const _WeeklyProgress({
    required this.plannedMinutes,
    required this.studiedMinutes,
    required this.completedSessions,
    required this.totalSessions,
  });

  final int plannedMinutes;
  final int studiedMinutes;
  final int completedSessions;
  final int totalSessions;
}