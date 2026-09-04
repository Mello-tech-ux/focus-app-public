import 'dart:async';

import 'package:flutter/material.dart';

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({
    super.key,
    required this.moduleName,
    required this.durationMinutes,
  });

  final String moduleName;
  final int durationMinutes;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  Timer? _timer;

  late int _remainingSeconds;

  bool _isRunning = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();

    _remainingSeconds = widget.durationMinutes * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isComplete || _isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          return;
        }

        if (_remainingSeconds <= 1) {
          _timer?.cancel();

          setState(() {
            _remainingSeconds = 0;
            _isRunning = false;
            _isComplete = true;
          });

          return;
        }

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  void _pauseTimer() {
    _timer?.cancel();

    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = widget.durationMinutes * 60;
      _isRunning = false;
      _isComplete = false;
    });
  }

  Future<void> _endSession() async {
    _timer?.cancel();

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('End session?'),
          content: const Text(
            'Your current session will end and the timer will stop.',
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

    if (shouldEnd == true && mounted) {
      Navigator.of(context).pop();
    } else if (mounted && !_isComplete) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _finish() {
    _timer?.cancel();

    Navigator.of(context).pop();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final totalSeconds = widget.durationMinutes * 60;

    if (totalSeconds == 0) {
      return 1;
    }

    return 1 - (_remainingSeconds / totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Session'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final timerSize = (constraints.maxWidth * 0.82)
                .clamp(180.0, 250.0);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                24,
                16,
                32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _isComplete
                            ? Icons.check_circle_rounded
                            : Icons.menu_book_rounded,
                        size: 56,
                        color: colors.primary,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _isComplete ? 'Session Complete' : 'Focus on',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        widget.moduleName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: timerSize,
                        height: timerSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: timerSize,
                              height: timerSize,
                              child: CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 10,
                                backgroundColor:
                                    colors.surfaceContainerHighest,
                              ),
                            ),

                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  _isComplete
                                      ? 'Well done.'
                                      : _isRunning
                                          ? 'Stay focused.'
                                          : 'Ready?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (!_isComplete)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
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
                                    horizontal: 20,
                                    vertical: 14,
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
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                              ),

                            OutlinedButton(
                              onPressed: _resetTimer,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
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

                      const SizedBox(height: 8),

                      if (!_isComplete)
                        TextButton(
                          onPressed: _endSession,
                          child: const Text('End Session'),
                        ),
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