import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({
    super.key,
    required this.sessionId,
    required this.moduleId,
    required this.moduleName,
    required this.durationMinutes,
  });

  final String sessionId;
  final String moduleId;
  final String moduleName;
  final int durationMinutes;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  Timer? _timer;

  late int _remainingSeconds;
  late int _elapsedSeconds;

  bool _isRunning = false;
  bool _isComplete = false;
  bool _isLoading = true;

  static const String _sessionProgressKey = 'focus_session_progress';
  static const String _moduleProgressKey = 'focus_module_progress';

  @override
  void initState() {
    super.initState();

    _remainingSeconds = widget.durationMinutes * 60;
    _elapsedSeconds = 0;

    _loadSessionState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // STORAGE HELPERS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadSavedSessions() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = preferences.getString(_sessionProgressKey);

    if (saved == null || saved.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupted saved data.
    }

    return {};
  }

  Future<Map<String, dynamic>> _loadModuleProgress() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = preferences.getString(_moduleProgressKey);

    if (saved == null || saved.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupted saved data.
    }

    return {};
  }

  // ---------------------------------------------------------------------------
  // LOAD SESSION
  // ---------------------------------------------------------------------------

  Future<void> _loadSessionState() async {
    final savedSessions = await _loadSavedSessions();
    final saved = savedSessions[widget.sessionId];

    if (!mounted) {
      return;
    }

    if (saved is Map) {
      final savedRemaining = saved['remainingSeconds'];
      final savedElapsed = saved['elapsedSeconds'];
      final savedComplete = saved['isComplete'];

      if (savedRemaining is num) {
        _remainingSeconds = savedRemaining
            .toInt()
            .clamp(0, widget.durationMinutes * 60);
      }

      if (savedElapsed is num) {
        _elapsedSeconds = savedElapsed
            .toInt()
            .clamp(0, widget.durationMinutes * 60);
      } else {
        _elapsedSeconds =
            (widget.durationMinutes * 60 - _remainingSeconds)
                .clamp(0, widget.durationMinutes * 60);
      }

      if (savedComplete is bool) {
        _isComplete = savedComplete;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // SAVE SESSION + MODULE PROGRESS
  // ---------------------------------------------------------------------------

  Future<void> _saveSessionState() async {
    final preferences = await SharedPreferences.getInstance();

    // Save this individual session.
    final savedSessions = await _loadSavedSessions();

    savedSessions[widget.sessionId] = {
      'moduleId': widget.moduleId,
      'remainingSeconds': _remainingSeconds,
      'elapsedSeconds': _elapsedSeconds,
      'isComplete': _isComplete,
    };

    await preferences.setString(
      _sessionProgressKey,
      jsonEncode(savedSessions),
    );

    // Save cumulative studied minutes for the module.
    //
    // This is intentionally separate from the timetable/session data.
    // Therefore, regenerating a timetable will not erase the module's
    // accumulated study time.
    if (widget.moduleId.isNotEmpty) {
      final moduleProgress = await _loadModuleProgress();

      final previousSeconds =
          moduleProgress[widget.moduleId] is num
              ? (moduleProgress[widget.moduleId] as num).toInt()
              : 0;

      final currentSessionSeconds = _elapsedSeconds;

      // We store the total contribution from this session separately so
      // repeated saves don't add the same seconds over and over.
      final sessionContributions =
          await _loadSessionContributions();

      final previousContribution =
          sessionContributions[widget.sessionId] is num
              ? (sessionContributions[widget.sessionId] as num).toInt()
              : 0;

      final difference =
          currentSessionSeconds - previousContribution;

      if (difference != 0) {
        final updatedTotal =
            (previousSeconds + difference).clamp(0, 1 << 30);

        moduleProgress[widget.moduleId] = updatedTotal;

        sessionContributions[widget.sessionId] =
            currentSessionSeconds;

        await preferences.setString(
          _moduleProgressKey,
          jsonEncode(moduleProgress),
        );

        await preferences.setString(
          _sessionContributionsKey,
          jsonEncode(sessionContributions),
        );
      }
    }
  }

  static const String _sessionContributionsKey =
      'focus_session_contributions';

  Future<Map<String, dynamic>> _loadSessionContributions() async {
    final preferences = await SharedPreferences.getInstance();

    final saved = preferences.getString(_sessionContributionsKey);

    if (saved == null || saved.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(saved);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupted saved data.
    }

    return {};
  }

  // ---------------------------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------------------------

  Future<void> _startTimer() async {
    if (_isComplete || _isRunning || _isLoading) {
      return;
    }

    setState(() {
      _isRunning = true;
    });

    // Save immediately when the session starts.
    await _saveSessionState();

    if (!mounted) {
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (!mounted) {
          return;
        }

        if (_remainingSeconds <= 1) {
          _timer?.cancel();

          setState(() {
            _remainingSeconds = 0;
            _elapsedSeconds = widget.durationMinutes * 60;
            _isRunning = false;
            _isComplete = true;
          });

          await _saveSessionState();
          return;
        }

        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });

        // Persist every second.
        //
        // If the application is completely closed, the latest saved
        // progress remains available when FOCUS is opened again.
        await _saveSessionState();
      },
    );
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _isRunning = false;
    });

    await _saveSessionState();
  }

  Future<void> _resetTimer() async {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = widget.durationMinutes * 60;
      _elapsedSeconds = 0;
      _isRunning = false;
      _isComplete = false;
    });

    await _saveSessionState();
  }

  // ---------------------------------------------------------------------------
  // END SESSION
  // ---------------------------------------------------------------------------

  Future<void> _endSession() async {
    _timer?.cancel();

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('End session?'),
          content: const Text(
            'Your current progress will be saved, but this session will end.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Keep studying'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('End session'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldEnd == true) {
      setState(() {
        _isRunning = false;
      });

      await _saveSessionState();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(false);
    } else if (!_isComplete) {
      setState(() {
        _isRunning = false;
      });

      await _saveSessionState();
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = 0;
      _elapsedSeconds = widget.durationMinutes * 60;
      _isRunning = false;
      _isComplete = true;
    });

    await _saveSessionState();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final totalSeconds = widget.durationMinutes * 60;

    if (totalSeconds <= 0) {
      return 1;
    }

    return 1 - (_remainingSeconds / totalSeconds);
  }

  String get _statusText {
    if (_isComplete) {
      return 'Well done.';
    }

    if (_isRunning) {
      return 'Stay focused.';
    }

    if (_remainingSeconds == widget.durationMinutes * 60) {
      return 'Ready?';
    }

    return 'Paused';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Study Session'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Session'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),

                      Icon(
                        _isComplete
                            ? Icons.check_circle_rounded
                            : Icons.menu_book_rounded,
                        size: 58,
                        color: colors.primary,
                      ),

                      const SizedBox(height: 18),

                      Text(
                        _isComplete
                            ? 'Session Complete'
                            : 'Focus on',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        widget.moduleName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: 230,
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 230,
                              height: 230,
                              child: CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 11,
                                backgroundColor:
                                    colors.surfaceContainerHighest,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatTime(_remainingSeconds),
                                      style: theme.textTheme.displayMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    _statusText,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      if (!_isComplete)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (_isRunning)
                              FilledButton.icon(
                                onPressed: _pauseTimer,
                                icon: const Icon(
                                  Icons.pause_rounded,
                                ),
                                label: const Text('Pause'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 15,
                                  ),
                                ),
                              )
                            else
                              FilledButton.icon(
                                onPressed: _startTimer,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                ),
                                label: Text(
                                  _remainingSeconds ==
                                          widget.durationMinutes * 60
                                      ? 'Start Session'
                                      : 'Resume',
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 15,
                                  ),
                                ),
                              ),

                            OutlinedButton(
                              onPressed: _resetTimer,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 15,
                                ),
                              ),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),

                      if (_isComplete)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _finish,
                            icon: const Icon(
                              Icons.check_rounded,
                            ),
                            label: const Text('Done'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      if (!_isComplete)
                        TextButton(
                          onPressed: _endSession,
                          child: const Text('End Session'),
                        ),

                      if (_isComplete) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Session recorded as complete.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}