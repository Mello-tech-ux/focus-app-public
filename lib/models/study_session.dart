import 'availability_window.dart';

class StudySession {
  const StudySession({
    required this.id,
    required this.moduleId,
    required this.day,
    required this.startMinute,
    required this.durationMinutes,
  }) : assert(startMinute >= 0 && startMinute < 24 * 60),
       assert(durationMinutes > 0);

  final String id;
  final String moduleId;
  final StudyDay day;
  final int startMinute;
  final int durationMinutes;

  int get endMinute => startMinute + durationMinutes;

  StudyTime get startTime => StudyTime(startMinute);

  StudyTime get endTime {
    if (endMinute >= 24 * 60) {
      throw StateError('Study session cannot extend past midnight.');
    }

    return StudyTime(endMinute);
  }

  String get startLabel => _formatTime(startMinute);

  String get endLabel => _formatTime(endMinute);

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}