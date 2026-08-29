import 'package:flutter/material.dart';

enum ModuleDifficulty { easy, moderate, difficult }

enum ModulePriority { low, normal, high }

class StudyModule {
  const StudyModule({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.priority,
    required this.color,
    this.code,
    this.weeklyStudyTargetHours,
  });

  final String id;
  final String name;
  final String? code;
  final ModuleDifficulty difficulty;
  final ModulePriority priority;
  final double? weeklyStudyTargetHours;
  final Color color;

  StudyModule copyWith({
    String? name,
    String? code,
    ModuleDifficulty? difficulty,
    ModulePriority? priority,
    double? weeklyStudyTargetHours,
    bool clearWeeklyStudyTarget = false,
    Color? color,
  }) {
    return StudyModule(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      difficulty: difficulty ?? this.difficulty,
      priority: priority ?? this.priority,
      weeklyStudyTargetHours: clearWeeklyStudyTarget
          ? null
          : weeklyStudyTargetHours ?? this.weeklyStudyTargetHours,
      color: color ?? this.color,
    );
  }
}

extension ModuleDifficultyLabel on ModuleDifficulty {
  String get label => switch (this) {
        ModuleDifficulty.easy => 'Easy',
        ModuleDifficulty.moderate => 'Moderate',
        ModuleDifficulty.difficult => 'Difficult',
      };
}

extension ModulePriorityLabel on ModulePriority {
  String get label => switch (this) {
        ModulePriority.low => 'Low',
        ModulePriority.normal => 'Normal',
        ModulePriority.high => 'High',
      };
}
