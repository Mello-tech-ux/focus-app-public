import 'package:flutter/material.dart';

import '../models/study_module.dart';
import '../models/study_plan.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({
    super.key,
    required this.modules,
    required this.initialPlans,
  });

  final List<StudyModule> modules;
  final List<StudyPlan> initialPlans;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  late List<StudyPlan> _plans;

  @override
  void initState() {
    super.initState();
    _plans = List<StudyPlan>.from(widget.initialPlans);
  }

  StudyPlan _planForModule(StudyModule module) {
    for (final plan in _plans) {
      if (plan.moduleId == module.id) {
        return plan;
      }
    }

    return StudyPlan(
      moduleId: module.id,
      mode: StudyPlanMode.automatic,
    );
  }

  void _savePlan(StudyPlan plan) {
    setState(() {
      final index = _plans.indexWhere(
        (existing) => existing.moduleId == plan.moduleId,
      );

      if (index == -1) {
        _plans = [..._plans, plan];
      } else {
        _plans[index] = plan;
      }
    });
  }

  Future<void> _configurePlan(StudyModule module) async {
    final result = await showModalBottomSheet<StudyPlan>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _StudyPlanEditor(
          module: module,
          initialPlan: _planForModule(module),
        );
      },
    );

    if (result != null && mounted) {
      _savePlan(result);
    }
  }

  void _finish() {
    Navigator.of(context).pop(_plans);
  }

  @override
  Widget build(BuildContext context) {
    final targetModules = widget.modules
        .where((module) => module.weeklyStudyTargetHours != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planning'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Done'),
          ),
        ],
      ),
      body: targetModules.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add a weekly study target to your modules first.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: targetModules.length,
              itemBuilder: (context, index) {
                final module = targetModules[index];
                final plan = _planForModule(module);

                final targetMinutes =
                    (module.weeklyStudyTargetHours! * 60).round();

                final allocatedMinutes = plan.totalAllocatedMinutes;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (module.code?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(module.code!),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Weekly target: ${_formatMinutes(targetMinutes)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Allocated: ${_formatMinutes(allocatedMinutes)} '
                          'of ${_formatMinutes(targetMinutes)}',
                        ),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(_modeLabel(plan.mode)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _configurePlan(module),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text(
                              'Configure distribution',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _modeLabel(StudyPlanMode mode) {
    switch (mode) {
      case StudyPlanMode.automatic:
        return 'Automatic';

      case StudyPlanMode.assisted:
        return 'Assisted';

      case StudyPlanMode.manual:
        return 'Manual';
    }
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }
}

class _StudyPlanEditor extends StatefulWidget {
  const _StudyPlanEditor({
    required this.module,
    required this.initialPlan,
  });

  final StudyModule module;
  final StudyPlan initialPlan;

  @override
  State<_StudyPlanEditor> createState() => _StudyPlanEditorState();
}

class _StudyPlanEditorState extends State<_StudyPlanEditor> {
  late StudyPlanMode _mode;
  late final List<TextEditingController> _controllers;

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();

    _mode = widget.initialPlan.mode;

    final minutes = [
      widget.initialPlan.mondayMinutes,
      widget.initialPlan.tuesdayMinutes,
      widget.initialPlan.wednesdayMinutes,
      widget.initialPlan.thursdayMinutes,
      widget.initialPlan.fridayMinutes,
      widget.initialPlan.saturdayMinutes,
      widget.initialPlan.sundayMinutes,
    ];

    _controllers = minutes
        .map(
          (value) => TextEditingController(
            text: value == 0 ? '' : value.toString(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _save() {
    final values = _controllers.map((controller) {
      return int.tryParse(controller.text.trim()) ?? 0;
    }).toList();

    final plan = StudyPlan(
      moduleId: widget.module.id,
      mode: _mode,
      mondayMinutes: values[0],
      tuesdayMinutes: values[1],
      wednesdayMinutes: values[2],
      thursdayMinutes: values[3],
      fridayMinutes: values[4],
      saturdayMinutes: values[5],
      sundayMinutes: values[6],
    );

    Navigator.of(context).pop(plan);
  }

  String _allocationMessage(int difference) {
    if (difference == 0) {
      return 'Target reached.';
    }

    if (difference > 0) {
      return '$difference min still need to be allocated.';
    }

    return '${-difference} min over the weekly target.';
  }

  Color _allocationColor(
    BuildContext context,
    int difference,
  ) {
    if (difference == 0) {
      return Theme.of(context).colorScheme.primary;
    }

    return Theme.of(context).colorScheme.error;
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final targetMinutes =
        (widget.module.weeklyStudyTargetHours! * 60).round();

    final allocatedMinutes = _controllers.fold<int>(
      0,
      (total, controller) {
        return total + (int.tryParse(controller.text.trim()) ?? 0);
      },
    );

    final difference = targetMinutes - allocatedMinutes;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.module.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),

              const SizedBox(height: 6),

              Text(
                'Weekly target: ${_formatMinutes(targetMinutes)}',
              ),

              const SizedBox(height: 20),

              Text(
                'Planning mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              RadioGroup<StudyPlanMode>(
                groupValue: _mode,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _mode = value;
                    });
                  }
                },
                child: Column(
                  children: [
                    const RadioListTile<StudyPlanMode>(
                      value: StudyPlanMode.automatic,
                      title: Text('Automatic'),
                      subtitle: Text(
                        'Let FOCUS decide how to distribute the time.',
                      ),
                    ),

                    const RadioListTile<StudyPlanMode>(
                      value: StudyPlanMode.assisted,
                      title: Text('Assisted'),
                      subtitle: Text(
                        'Give FOCUS a rough distribution to work with.',
                      ),
                    ),

                    const RadioListTile<StudyPlanMode>(
                      value: StudyPlanMode.manual,
                      title: Text('Manual'),
                      subtitle: Text(
                        'Choose exactly how much time to allocate each day.',
                      ),
                    ),
                  ],
                ),
              ),

              if (_mode != StudyPlanMode.automatic) ...[
                const SizedBox(height: 12),

                Text(
                  'Daily allocation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 8),

                ...List.generate(
                  _days.length,
                  (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _days[index],
                          suffixText: 'min',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                Text(
                  'Allocated: $allocatedMinutes min',
                ),

                const SizedBox(height: 4),

                Text(
                  _allocationMessage(difference),
                  style: TextStyle(
                    color: _allocationColor(
                      context,
                      difference,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text(
                    'Save distribution',
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
