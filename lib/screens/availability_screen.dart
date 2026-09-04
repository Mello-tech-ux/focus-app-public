
import 'package:flutter/material.dart';

import '../models/availability_window.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({
    super.key,
    required this.initialWindows,
  });

  final List<AvailabilityWindow> initialWindows;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late List<AvailabilityWindow> _windows;

  @override
  void initState() {
    super.initState();
    _windows = List<AvailabilityWindow>.from(widget.initialWindows);
  }

  List<AvailabilityWindow> _forDay(StudyDay day) {
    final windows =
        _windows.where((window) => window.day == day).toList();

    windows.sort(
      (a, b) => a.startTime.compareTo(b.startTime),
    );

    return windows;
  }

  Future<void> _addOrEdit(
    StudyDay day, [
    AvailabilityWindow? existing,
  ]) async {
    final start = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : _toTimeOfDay(existing.startTime),
      helpText: 'Select start time',
    );

    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : _toTimeOfDay(existing.endTime),
      helpText: 'Select end time',
    );

    if (end == null || !mounted) return;

    final startTime = _toStudyTime(start);
    final endTime = _toStudyTime(end);

    if (startTime.compareTo(endTime) >= 0) {
      _showError('End time must be after start time.');
      return;
    }

    final candidate = AvailabilityWindow(
      id: existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      day: day,
      startTime: startTime,
      endTime: endTime,
    );

    if (hasOverlappingAvailability(_windows, candidate)) {
      _showError(
        'This overlaps another availability window on ${day.label}.',
      );
      return;
    }

    setState(() {
      final index = _windows.indexWhere(
        (window) => window.id == candidate.id,
      );

      if (index == -1) {
        _windows.add(candidate);
      } else {
        _windows[index] = candidate;
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _delete(AvailabilityWindow window) {
    setState(() {
      _windows.removeWhere(
        (item) => item.id == window.id,
      );
    });
  }

  Future<void> _copyDay(StudyDay source) async {
    final selected = <StudyDay>{};

    final targets = await showDialog<Set<StudyDay>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Copy ${source.label} to'),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: StudyDay.values
                      .where((day) => day != source)
                      .map(
                        (day) => CheckboxListTile(
                          value: selected.contains(day),
                          title: Text(day.label),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(day);
                              } else {
                                selected.remove(day);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            selected,
                          ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (targets == null || targets.isEmpty || !mounted) {
      return;
    }

    final hasExisting = targets.any(
      (day) => _forDay(day).isNotEmpty,
    );

    if (hasExisting) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Replace existing availability?',
            ),
            content: const Text(
              'Some selected days already have availability. '
              'Their windows will be replaced.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  false,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  true,
                ),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );

      if (overwrite != true || !mounted) {
        return;
      }
    }

    final sourceWindows = _forDay(source);

    setState(() {
      for (final target in targets) {
        _windows.removeWhere(
          (window) => window.day == target,
        );

        for (final window in sourceWindows) {
          _windows.add(
            AvailabilityWindow(
              id:
                  '${window.id}-${target.name}-${DateTime.now().microsecondsSinceEpoch}',
              day: target,
              startTime: window.startTime,
              endTime: window.endTime,
            ),
          );
        }
      }
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      List<AvailabilityWindow>.from(_windows),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('When can you study?'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        itemCount: StudyDay.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final day = StudyDay.values[index];

          return _DayCard(
            day: day,
            windows: _forDay(day),
            onAdd: () => _addOrEdit(day),
            onEdit: (window) => _addOrEdit(
              day,
              window,
            ),
            onDelete: _delete,
            onCopy: () => _copyDay(day),
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.windows,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
  });

  final StudyDay day;
  final List<AvailabilityWindow> windows;
  final VoidCallback onAdd;
  final ValueChanged<AvailabilityWindow> onEdit;
  final ValueChanged<AvailabilityWindow> onDelete;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  tooltip:
                      'Copy ${day.label} to other days',
                  icon: const Icon(
                    Icons.content_copy_outlined,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (windows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  top: 4,
                ),
                child: Text(
                  'Unavailable',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...windows.map(
                (window) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.schedule_outlined,
                    color: colors.primary,
                  ),
                  title: Text(
                    '${_formatTime(context, window.startTime)}'
                    '–'
                    '${_formatTime(context, window.endTime)}',
                  ),
                  trailing:
                      PopupMenuButton<_WindowAction>(
                    onSelected: (action) {
                      if (action ==
                          _WindowAction.edit) {
                        onEdit(window);
                      }

                      if (action ==
                          _WindowAction.delete) {
                        onDelete(window);
                      }
                    },
                    itemBuilder: (context) =>
                        const [
                      PopupMenuItem(
                        value: _WindowAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _WindowAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _WindowAction {
  edit,
  delete,
}

StudyTime _toStudyTime(TimeOfDay time) {
  return StudyTime(
    time.hour * 60 + time.minute,
  );
}

TimeOfDay _toTimeOfDay(StudyTime time) {
  return TimeOfDay(
    hour: time.hour,
    minute: time.minute,
  );
}

String _formatTime(
  BuildContext context,
  StudyTime time,
) {
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(
    _toTimeOfDay(time),
  );
}

