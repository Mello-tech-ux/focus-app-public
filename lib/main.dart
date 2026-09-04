import 'dart:async';

import 'package:flutter/material.dart';

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
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const FocusHomeScreen(),
                        ),
                      );
                    },
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
  List<StudyModule> _modules = [];

  final List<AvailabilityWindow> _availability = [];

  StudyPreferences _preferences = const StudyPreferences();

  List<StudyPlan> _studyPlans = [];

  List<StudySession> _studySessions = [];

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
    }
  }

  Future<void> _openAvailability() async {
    final windows =
        await Navigator.of(context).push<List<AvailabilityWindow>>(
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
    }
  }

  Future<void> _openPreferences() async {
    final preferences =
        await Navigator.of(context).push<StudyPreferences>(
      MaterialPageRoute<StudyPreferences>(
        builder: (_) => StudyPreferencesScreen(
          initialPreferences: _preferences,
        ),
      ),
    );

    if (preferences != null && mounted) {
      setState(() {
        _preferences = preferences;
      });
    }
  }

  Future<void> _openStudyPlan() async {
    final plans =
        await Navigator.of(context).push<List<StudyPlan>>(
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
    }
  }

  void _generateTimetable() {
    final modulesWithTargets = _modules
        .where(
          (module) => module.weeklyStudyTargetHours != null,
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

    final scheduler = const StudyScheduler();

    final sessions = scheduler.generate(
      modules: _modules,
      availability: _availability,
      preferences: _preferences,
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
    });

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

  StudyModule? _moduleForSession(StudySession session) {
    for (final module in _modules) {
      if (module.id == session.moduleId) {
        return module;
      }
    }

    return null;
  }

  List<StudySession> _todaySessions() {
    final today = StudyDay.values[DateTime.now().weekday - 1];

    final sessions = _studySessions
        .where((session) => session.day == today)
        .toList();

    sessions.sort(
      (a, b) => a.startMinute.compareTo(b.startMinute),
    );

    return sessions;
  }

  StudySession? _nextSession() {
    if (_studySessions.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final currentMinute = now.hour * 60 + now.minute;

    final upcoming = _studySessions.where((session) {
      final sessionDayIndex = StudyDay.values.indexOf(session.day);

      if (sessionDayIndex > todayIndex) {
        return true;
      }

      if (sessionDayIndex == todayIndex &&
          session.startMinute >= currentMinute) {
        return true;
      }

      return false;
    }).toList();

    if (upcoming.isEmpty) {
      return null;
    }

    upcoming.sort((a, b) {
      final dayComparison = StudyDay.values
          .indexOf(a.day)
          .compareTo(StudyDay.values.indexOf(b.day));

      if (dayComparison != 0) {
        return dayComparison;
      }

      return a.startMinute.compareTo(b.startMinute);
    });

    return upcoming.first;
  }

  void _startSession(StudySession session) {
    final module = _moduleForSession(session);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudySessionScreen(
          moduleName: module?.name ?? 'Unknown module',
          durationMinutes: session.durationMinutes,
        ),
      ),
    );
  }

  String _formatTotalStudyTime() {
    final totalMinutes = _studySessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }

    if (hours > 0) {
      return '${hours}h';
    }

    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final todaySessions = _todaySessions();
    final nextSession = _nextSession();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FOCUS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Stay focused.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),

          const SizedBox(height: 6),

          Text(
            'Plan your week. Study consistently.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),

          const SizedBox(height: 24),

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
              onTap: _generateTimetable,
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
                onTap: _openTimetable,
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
              onTap: _openAvailability,
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
              onTap: _openPreferences,
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
              onTap: _openStudyPlan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection(
    BuildContext context,
    List<StudySession> sessions,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Study",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),

        const SizedBox(height: 10),

        if (sessions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: colors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studySessions.isEmpty
                              ? 'No timetable yet'
                              : 'Nothing scheduled today',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _studySessions.isEmpty
                              ? 'Generate your timetable to see your study sessions here.'
                              : 'Enjoy the free time. Your next session will appear above.',
                          style: Theme.of(context)
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
            (session) => _buildHomeSessionCard(
              context,
              session,
            ),
          ),
      ],
    );
  }

  Widget _buildHomeSessionCard(
    BuildContext context,
    StudySession session,
  ) {
    final module = _moduleForSession(session);
    final moduleColor =
        module?.color ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _startSession(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 70,
                decoration: BoxDecoration(
                  color: moduleColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      module?.name ?? 'Unknown module',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${session.startLabel} – ${session.endLabel}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${session.durationMinutes} min',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              FilledButton(
                onPressed: () => _startSession(session),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextSessionSection(
    BuildContext context,
    StudySession session,
  ) {
    final module = _moduleForSession(session);
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upcoming_rounded,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Up Next',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              module?.name ?? 'Unknown module',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onPrimaryContainer,
                  ),
            ),

            const SizedBox(height: 5),

            Text(
              '${session.day.label} • '
              '${session.startLabel} – ${session.endLabel}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startSession(session),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                ),
                label: const Text('Start Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.insights_rounded,
              size: 32,
              color: colors.primary,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Week',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_studySessions.length} '
                    '${_studySessions.length == 1 ? 'session' : 'sessions'}'
                    ' • ${_formatTotalStudyTime()} planned',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}