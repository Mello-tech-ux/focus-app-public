import 'package:flutter/material.dart';

import '../models/availability_window.dart';
import '../models/study_preferences.dart';

class StudyPreferencesScreen extends StatefulWidget {
  const StudyPreferencesScreen({super.key, required this.initialPreferences});

  final StudyPreferences initialPreferences;

  @override
  State<StudyPreferencesScreen> createState() => _StudyPreferencesScreenState();
}

class _StudyPreferencesScreenState extends State<StudyPreferencesScreen> {
  static const _sessionOptions = [25, 45, 60, 90];
  static const _breakOptions = [5, 10, 15];
  static const _dailyOptions = [60, 120, 180, 240];

  late PreferredStudyPeriod _period;
  late int _sessionMinutes;
  late int _breakMinutes;
  late int? _maximumDailyMinutes;
  late Set<StudyDay> _restDays;
  late final TextEditingController _customSessionController;
  late final TextEditingController _customBreakController;
  late final TextEditingController _customDailyController;

  @override
  void initState() {
    super.initState();
    final preferences = widget.initialPreferences;
    _period = preferences.preferredStudyPeriod;
    _sessionMinutes = preferences.preferredSessionMinutes;
    _breakMinutes = preferences.preferredBreakMinutes;
    _maximumDailyMinutes = preferences.maximumDailyStudyMinutes;
    _restDays = Set.of(preferences.restDays);
    _customSessionController = TextEditingController(
      text: _sessionOptions.contains(_sessionMinutes) ? '' : '$_sessionMinutes',
    );
    _customBreakController = TextEditingController(
      text: _breakOptions.contains(_breakMinutes) ? '' : '$_breakMinutes',
    );
    _customDailyController = TextEditingController(
      text: _maximumDailyMinutes == null || _dailyOptions.contains(_maximumDailyMinutes)
          ? ''
          : '$_maximumDailyMinutes',
    );
  }

  @override
  void dispose() {
    _customSessionController.dispose();
    _customBreakController.dispose();
    _customDailyController.dispose();
    super.dispose();
  }

  bool get _usesCustomSession => !_sessionOptions.contains(_sessionMinutes);
  bool get _usesCustomBreak => !_breakOptions.contains(_breakMinutes);
  bool get _usesCustomDaily =>
      _maximumDailyMinutes != null && !_dailyOptions.contains(_maximumDailyMinutes);

  void _save() {
    final session = _usesCustomSession
        ? int.tryParse(_customSessionController.text.trim())
        : _sessionMinutes;
    final breakLength = _usesCustomBreak
        ? int.tryParse(_customBreakController.text.trim())
        : _breakMinutes;
    final daily = _usesCustomDaily
        ? int.tryParse(_customDailyController.text.trim())
        : _maximumDailyMinutes;
    if (session == null || session <= 0 || breakLength == null || breakLength <= 0) {
      _showError('Enter a session and break length greater than 0.');
      return;
    }
    if (_usesCustomDaily && (daily == null || daily <= 0)) {
      _showError('Enter a daily limit greater than 0.');
      return;
    }
    Navigator.of(context).pop(
      StudyPreferences(
        preferredStudyPeriod: _period,
        preferredSessionMinutes: session,
        preferredBreakMinutes: breakLength,
        maximumDailyStudyMinutes: daily,
        restDays: _restDays,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How do you prefer to study?'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'These preferences guide future study suggestions. They do not change when you are available.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _PreferenceCard(
            title: 'Preferred study period',
            child: DropdownButtonFormField<PreferredStudyPeriod>(
              initialValue: _period,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: PreferredStudyPeriod.values
                  .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                  .toList(),
              onChanged: (value) => setState(() => _period = value!),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceCard(
            title: 'Preferred session length',
            child: _DurationSelector(
              initialValue: _usesCustomSession ? -1 : _sessionMinutes,
              choices: _sessionOptions,
              noLimit: false,
              customController: _customSessionController,
              onChanged: (value) => setState(() {
                _sessionMinutes = value == -1 ? -1 : value;
              }),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceCard(
            title: 'Preferred break length',
            child: _DurationSelector(
              initialValue: _usesCustomBreak ? -1 : _breakMinutes,
              choices: _breakOptions,
              noLimit: false,
              customController: _customBreakController,
              onChanged: (value) => setState(() {
                _breakMinutes = value == -1 ? -1 : value;
              }),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceCard(
            title: 'Maximum daily study time',
            child: _DurationSelector(
              initialValue: _maximumDailyMinutes == null
                  ? 0
                  : (_usesCustomDaily ? -1 : _maximumDailyMinutes!),
              choices: _dailyOptions,
              noLimit: true,
              customController: _customDailyController,
              onChanged: (value) => setState(() {
                _maximumDailyMinutes = value == 0 ? null : value;
              }),
            ),
          ),
          const SizedBox(height: 14),
          _PreferenceCard(
            title: 'Rest days',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StudyDay.values
                  .map(
                    (day) => FilterChip(
                      label: Text(day.label.substring(0, 3)),
                      selected: _restDays.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _restDays.add(day);
                        } else {
                          _restDays.remove(day);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save preferences')),
        ],
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({
    required this.initialValue,
    required this.choices,
    required this.noLimit,
    required this.customController,
    required this.onChanged,
  });

  final int initialValue;
  final List<int> choices;
  final bool noLimit;
  final TextEditingController customController;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: initialValue,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            ...choices.map(
              (minutes) => DropdownMenuItem(
                value: minutes,
                child: Text(_durationLabel(minutes)),
              ),
            ),
            if (noLimit) const DropdownMenuItem(value: 0, child: Text('No limit')),
            const DropdownMenuItem(value: -1, child: Text('Custom')),
          ],
          onChanged: (selected) => onChanged(selected!),
        ),
        if (initialValue == -1) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custom minutes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

String _durationLabel(int minutes) => minutes % 60 == 0
    ? '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}'
    : '$minutes minutes';
