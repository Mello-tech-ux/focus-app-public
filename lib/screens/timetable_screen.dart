import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late List<StudySession> _sessions;

  Map<String, dynamic> _sessionProgress = <String, dynamic>{};

  bool _isLoadingProgress = true;

  static const String _progressStorageKey =
      'focus_session_progress';

  @override
  void initState() {
    super.initState();

    _sessions = List<StudySession>.from(widget.sessions);

    _loadSessionProgress();
  }

  // ---------------------------------------------------------------------------
  // PROGRESS PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> _loadSessionProgress() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = preferences.getString(_progressStorageKey);

    Map<String, dynamic> progress = <String, dynamic>{};

    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);

        if (decoded is Map) {
          progress = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        progress = <String, dynamic>{};
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionProgress = progress;
      _isLoadingProgress = false;
    });
  }

  Future<void> _refreshProgress() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = preferences.getString(_progressStorageKey);

    Map<String, dynamic> progress = <String, dynamic>{};

    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);

        if (decoded is Map) {
          progress = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        progress = <String, dynamic>{};
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sessionProgress = progress;
    });
  }

  // ---------------------------------------------------------------------------
  // MODULE / SESSION HELPERS
  // ---------------------------------------------------------------------------

  StudyModule? _moduleForSession(StudySession session) {
    for (final module in widget.modules) {
      if (module.id == session.moduleId) {
        return module;
      }
    }

    return null;
  }

  List<StudySession> _sessionsForDay(StudyDay day) {
    final sessions = _sessions
        .where((session) => session.day == day)
        .toList();

    sessions.sort(
      (a, b) => a.startMinute.compareTo(b.startMinute),
    );

    return sessions;
  }

  Map<String, dynamic>? _progressForSession(
    StudySession session,
  ) {
    final saved = _sessionProgress[session.id];

    if (saved is Map<String, dynamic>) {
      return saved;
    }

    if (saved is Map) {
      return Map<String, dynamic>.from(saved);
    }

    return null;
  }

  int _studiedSecondsForSession(StudySession session) {
    final saved = _progressForSession(session);

    if (saved == null) {
      return 0;
    }

    final elapsed = saved['elapsedSeconds'];

    if (elapsed is num) {
      return elapsed
          .toInt()
          .clamp(0, session.durationMinutes * 60);
    }

    final remaining = saved['remainingSeconds'];

    if (remaining is num) {
      final totalSeconds = session.durationMinutes * 60;

      return (totalSeconds - remaining.toInt())
          .clamp(0, totalSeconds);
    }

    return 0;
  }

  int _studiedMinutesForSession(StudySession session) {
    return _studiedSecondsForSession(session) ~/ 60;
  }

  bool _isCompleted(StudySession session) {
    final saved = _progressForSession(session);

    return saved?['isComplete'] == true;
  }

  bool _isInProgress(StudySession session) {
    return !_isCompleted(session) &&
        _studiedSecondsForSession(session) > 0;
  }

  // ---------------------------------------------------------------------------
  // SESSION OPENING
  // ---------------------------------------------------------------------------

  Future<void> _openSession(StudySession session) async {
    final module = _moduleForSession(session);

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudySessionScreen(
          sessionId: session.id,
          moduleName: module?.name ?? 'Unknown module',
          moduleId: session.moduleId,
          durationMinutes: session.durationMinutes,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshProgress();
  }

  // ---------------------------------------------------------------------------
  // SESSION EDITING
  // ---------------------------------------------------------------------------

  Future<void> _editSession(StudySession session) async {
    final result = await showModalBottomSheet<StudySession>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _EditSessionSheet(
          session: session,
          modules: widget.modules,
          existingSessions: _sessions,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      final index = _sessions.indexWhere(
        (item) => item.id == session.id,
      );

      if (index != -1) {
        _sessions[index] = result;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // WEEKLY TOTALS
  // ---------------------------------------------------------------------------

  int get _plannedMinutes {
    return _sessions.fold<int>(
      0,
      (total, session) => total + session.durationMinutes,
    );
  }

  int get _studiedMinutes {
    return _sessions.fold<int>(
      0,
      (total, session) =>
          total + _studiedMinutesForSession(session),
    );
  }

  int get _completedSessions {
    return _sessions.where(_isCompleted).length;
  }

  double get _completionPercentage {
    if (_plannedMinutes <= 0) {
      return 0;
    }

    return ((_studiedMinutes / _plannedMinutes) * 100)
        .clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _formatStudyTime(int totalMinutes) {
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selectedDay = StudyDay.values[_selectedDayIndex];
    final daySessions = _sessionsForDay(selectedDay);

    if (_isLoadingProgress) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Timetable'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                ? _buildEmptyDay(
                    context,
                    selectedDay,
                  )
                : _buildSessions(
                    context,
                    daySessions,
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final percentage = _completionPercentage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                      '${_sessions.length} '
                      '${_sessions.length == 1 ? 'session' : 'sessions'}'
                      ' • ${_formatStudyTime(_plannedMinutes)} study time',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                color: colors.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Weekly Progress',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  colors.onPrimaryContainer,
                            ),
                      ),
                    ),
                    Text(
                      '${percentage.round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                            color:
                                colors.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 9,
                    backgroundColor:
                        colors.onPrimaryContainer
                            .withValues(alpha: 0.12),
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  '${_formatStudyTime(_studiedMinutes)} studied '
                  'of ${_formatStudyTime(_plannedMinutes)} planned',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            colors.onPrimaryContainer,
                      ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$_completedSessions of '
                  '${_sessions.length} sessions complete',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DAY SELECTOR
  // ---------------------------------------------------------------------------

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
          final selected =
              index == _selectedDayIndex;

          final sessionCount =
              _sessionsForDay(day).length;

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
                duration:
                    const Duration(milliseconds: 200),
                width: 68,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortDayName(day),
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(
                                  alpha: 0.15,
                                )
                            : Theme.of(context)
                                .colorScheme
                                .surface,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$sessionCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
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

  // ---------------------------------------------------------------------------
  // SESSION LIST
  // ---------------------------------------------------------------------------

  Widget _buildSessions(
    BuildContext context,
    List<StudySession> sessions,
  ) {
    final items = <Widget>[];

    for (var index = 0;
        index < sessions.length;
        index++) {
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
            nextSession.startMinute -
                currentSession.endMinute;

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

  // ---------------------------------------------------------------------------
  // SESSION CARD
  // ---------------------------------------------------------------------------

  Widget _buildSession(
    BuildContext context,
    StudySession session,
  ) {
    final module = _moduleForSession(session);

    final completed = _isCompleted(session);
    final inProgress = _isInProgress(session);

    final studiedMinutes =
        _studiedMinutesForSession(session);

    final moduleColor =
        module?.color ??
            Theme.of(context)
                .colorScheme
                .primary;

    final remainingMinutes =
        (session.durationMinutes - studiedMinutes)
            .clamp(0, session.durationMinutes);

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: completed
            ? null
            : () => _openSession(session),
        onLongPress: () => _editSession(session),
        borderRadius:
            BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    session.startLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w800,
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
                  color: completed
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                      : moduleColor.withValues(
                          alpha: 0.10,
                        ),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: completed
                        ? Theme.of(context)
                            .colorScheme
                            .outlineVariant
                        : moduleColor.withValues(
                            alpha: 0.30,
                          ),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration:
                            BoxDecoration(
                          color: completed
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : moduleColor,
                          borderRadius:
                              const BorderRadius
                                  .horizontal(
                            left:
                                Radius.circular(16),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            15,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            module?.name ??
                                                'Unknown module',
                                            style: Theme.of(
                                                    context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight:
                                                      FontWeight
                                                          .w800,
                                                ),
                                          ),
                                        ),
                                        if (completed)
                                          Icon(
                                            Icons
                                                .check_circle_rounded,
                                            color: Theme.of(
                                                    context)
                                                .colorScheme
                                                .primary,
                                            size: 24,
                                          ),
                                      ],
                                    ),

                                    if (module
                                            ?.code
                                            ?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        module!.code!,
                                        style: Theme.of(
                                                context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Row(
                                      children: [
                                        const Icon(
                                          Icons
                                              .timer_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          '${session.durationMinutes} min',
                                          style: Theme.of(
                                                  context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                        ),
                                      ],
                                    ),

                                    if (inProgress) ...[
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          20,
                                        ),
                                        child:
                                            LinearProgressIndicator(
                                          value:
                                              session.durationMinutes <=
                                                      0
                                                  ? 0
                                                  : studiedMinutes /
                                                      session
                                                          .durationMinutes,
                                          minHeight: 6,
                                          backgroundColor:
                                              moduleColor
                                                  .withValues(
                                            alpha: 0.12,
                                          ),
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(
                                            moduleColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        '$studiedMinutes min studied • '
                                        '$remainingMinutes min left',
                                        style: Theme.of(
                                                context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                      ),
                                    ] else ...[
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        completed
                                            ? 'Session completed'
                                            : 'Tap to start • Hold to edit',
                                        style: Theme.of(
                                                context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                      context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              IconButton(
                                tooltip: completed
                                    ? 'Completed'
                                    : 'Start session',
                                onPressed: completed
                                    ? null
                                    : () => _openSession(
                                          session,
                                        ),
                                icon: Icon(
                                  completed
                                      ? Icons.check_rounded
                                      : Icons
                                          .play_circle_outline_rounded,
                                  color: completed
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                      : moduleColor,
                                  size: 30,
                                ),
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

  // ---------------------------------------------------------------------------
  // BREAK
  // ---------------------------------------------------------------------------

  Widget _buildBreak(
    BuildContext context,
    int startMinute,
    int endMinute,
    int duration,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final startTime =
        _minuteToTimeOfDay(startMinute);

    final endTime =
        _minuteToTimeOfDay(endMinute);

    return Padding(
      padding: const EdgeInsets.only(
        left: 72,
        bottom: 10,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color:
              colors.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.free_breakfast_rounded,
              size: 18,
              color:
                  colors.onSurfaceVariant,
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
                          fontWeight:
                              FontWeight.w800,
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
                          color:
                              colors.onSurfaceVariant,
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

  // ---------------------------------------------------------------------------
  // EMPTY DAY
  // ---------------------------------------------------------------------------

  Widget _buildEmptyDay(
    BuildContext context,
    StudyDay day,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
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
                    fontWeight:
                        FontWeight.w800,
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

  // ---------------------------------------------------------------------------
  // DAY / TIME HELPERS
  // ---------------------------------------------------------------------------

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

  TimeOfDay _minuteToTimeOfDay(
    int minutes,
  ) {
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

// =============================================================================
// EDIT SESSION SHEET
// =============================================================================

class _EditSessionSheet extends StatefulWidget {
  const _EditSessionSheet({
    required this.session,
    required this.modules,
    required this.existingSessions,
  });

  final StudySession session;
  final List<StudyModule> modules;
  final List<StudySession> existingSessions;

  @override
  State<_EditSessionSheet> createState() =>
      _EditSessionSheetState();
}

class _EditSessionSheetState
    extends State<_EditSessionSheet> {
  late String _selectedModuleId;
  late StudyDay _selectedDay;
  late TimeOfDay _selectedTime;
  late int _durationMinutes;

  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();

    _selectedModuleId = widget.session.moduleId;
    _selectedDay = widget.session.day;
    _selectedTime =
        _minuteToTimeOfDay(widget.session.startMinute);
    _durationMinutes = widget.session.durationMinutes;

    _durationController = TextEditingController(
      text: _durationMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  TimeOfDay _minuteToTimeOfDay(int minutes) {
    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  Future<void> _chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTime = picked;
    });
  }

  void _save() {
    final duration =
        int.tryParse(_durationController.text.trim());

    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid duration in minutes.',
          ),
        ),
      );
      return;
    }

    if (_selectedModuleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a module.',
          ),
        ),
      );
      return;
    }

    final startMinute = _timeToMinutes(_selectedTime);
    final endMinute = startMinute + duration;

    if (endMinute > 24 * 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This session cannot extend past midnight.',
          ),
        ),
      );
      return;
    }

    // Check whether the edited session would overlap
    // another session on the same day.
    final overlaps = widget.existingSessions.any(
      (other) {
        if (other.id == widget.session.id) {
          return false;
        }

        if (other.day != _selectedDay) {
          return false;
        }

        return startMinute < other.endMinute &&
            endMinute > other.startMinute;
      },
    );

    if (overlaps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That time overlaps another study session.',
          ),
        ),
      );
      return;
    }

    final updatedSession = StudySession(
      id: widget.session.id,
      moduleId: _selectedModuleId,
      day: _selectedDay,
      startMinute: startMinute,
      durationMinutes: duration,
    );

    Navigator.of(context).pop(updatedSession);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Session',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Change when, what, or how long you study.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Module',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue:
                    widget.modules.any(
                      (module) =>
                          module.id == _selectedModuleId,
                    )
                        ? _selectedModuleId
                        : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.menu_book_rounded),
                ),
                items: widget.modules.map(
                  (module) {
                    return DropdownMenuItem<String>(
                      value: module.id,
                      child: Text(
                        module.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedModuleId = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              Text(
                'Day',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<StudyDay>(
                initialValue: _selectedDay,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.calendar_today_rounded),
                ),
                items: StudyDay.values.map(
                  (day) {
                    return DropdownMenuItem<StudyDay>(
                      value: day,
                      child: Text(day.label),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedDay = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              Text(
                'Start time',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              InkWell(
                onTap: _chooseTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.schedule_rounded),
                  ),
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(
                      _selectedTime,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Duration',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _durationController,
                keyboardType:
                    TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.timer_outlined),
                  suffixText: 'min',
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Changes'),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}