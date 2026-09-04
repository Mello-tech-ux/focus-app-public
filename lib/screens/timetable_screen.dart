import 'package:flutter/material.dart';

import '../models/availability_window.dart';
import '../models/study_module.dart';
import '../models/study_session.dart';
import 'study_session_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    required this.modules,
    required this.sessions,
  });

  final List<StudyModule> modules;
  final List<StudySession> sessions;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _selectedDayIndex = DateTime.now().weekday - 1;

  StudyModule? _moduleForSession(StudySession session) {
    for (final module in widget.modules) {
      if (module.id == session.moduleId) {
        return module;
      }
    }

    return null;
  }

  List<StudySession> _sessionsForDay(StudyDay day) {
    final sessions = widget.sessions
        .where((session) => session.day == day)
        .toList();

    sessions.sort(
      (a, b) => a.startMinute.compareTo(b.startMinute),
    );

    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = StudyDay.values[_selectedDayIndex];
    final daySessions = _sessionsForDay(selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timetable'),
      ),
      body: Column(
        children: [
          _buildHeader(context),
          _buildDaySelector(context),
          Expanded(
            child: daySessions.isEmpty
                ? _buildEmptyDay(context, selectedDay)
                : _buildSessions(context, daySessions),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final totalMinutes = widget.sessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    final totalText = hours > 0
        ? '$hours${minutes > 0 ? 'h ${minutes}m' : 'h'}'
        : '${minutes}m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Week',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.sessions.length} '
                  '${widget.sessions.length == 1 ? 'session' : 'sessions'}'
                  ' • $totalText study time',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ],
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: StudyDay.values.length,
        itemBuilder: (context, index) {
          final day = StudyDay.values[index];
          final selected = index == _selectedDayIndex;
          final sessionCount = _sessionsForDay(day).length;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDayIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortDayName(day),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$sessionCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessions(
    BuildContext context,
    List<StudySession> sessions,
  ) {
    final items = <Widget>[];

    for (var index = 0; index < sessions.length; index++) {
      final currentSession = sessions[index];

      items.add(
        _buildSession(
          context,
          currentSession,
        ),
      );

      if (index < sessions.length - 1) {
        final nextSession = sessions[index + 1];

        final gap =
            nextSession.startMinute - currentSession.endMinute;

        if (gap > 0) {
          items.add(
            _buildBreak(
              context,
              currentSession.endMinute,
              nextSession.startMinute,
              gap,
            ),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24,
      ),
      children: items,
    );
  }

  Widget _buildSession(
    BuildContext context,
    StudySession session,
  ) {
    final module = _moduleForSession(session);

    final moduleColor =
        module?.color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StudySessionScreen(
                moduleName: module?.name ?? 'Unknown module',
                durationMinutes: session.durationMinutes,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.startLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session.endLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: moduleColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: moduleColor.withValues(alpha: 0.30),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: moduleColor,
                          borderRadius:
                              const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module?.name ??
                                          'Unknown module',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                    ),
                                    if (module?.code?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        module!.code!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${session.durationMinutes} min',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to start session',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.play_circle_outline_rounded,
                                color: moduleColor,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreak(
    BuildContext context,
    int startMinute,
    int endMinute,
    int duration,
  ) {
    final colors = Theme.of(context).colorScheme;

    final startTime = _minuteToTimeOfDay(startMinute);
    final endTime = _minuteToTimeOfDay(endMinute);

    return Padding(
      padding: const EdgeInsets.only(
        left: 72,
        bottom: 10,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.free_breakfast_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'BREAK',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(context, startTime)} – '
                    '${_formatTime(context, endTime)} • '
                    '$duration min',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDay(
    BuildContext context,
    StudyDay day,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.free_breakfast_rounded,
              size: 54,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            Text(
              '${day.label} is clear',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No study sessions are scheduled for this day.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _shortDayName(StudyDay day) {
    switch (day) {
      case StudyDay.monday:
        return 'MON';
      case StudyDay.tuesday:
        return 'TUE';
      case StudyDay.wednesday:
        return 'WED';
      case StudyDay.thursday:
        return 'THU';
      case StudyDay.friday:
        return 'FRI';
      case StudyDay.saturday:
        return 'SAT';
      case StudyDay.sunday:
        return 'SUN';
    }
  }

  TimeOfDay _minuteToTimeOfDay(int minutes) {
    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  String _formatTime(
    BuildContext context,
    TimeOfDay time,
  ) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(time);
  }
}