/// One focus block started from the focus timer.
class FocusSession {
  const FocusSession({
    required this.startedAt,
    required this.plannedMinutes,
    required this.focusedMinutes,
    required this.completed,
  });

  final DateTime startedAt;

  /// Length the user chose before starting.
  final int plannedMinutes;

  /// Minutes actually spent focusing (less than planned if ended early).
  final int focusedMinutes;

  /// True when the countdown reached zero.
  final bool completed;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'plannedMinutes': plannedMinutes,
    'focusedMinutes': focusedMinutes,
    'completed': completed,
  };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    startedAt:
        DateTime.tryParse(json['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    plannedMinutes: (json['plannedMinutes'] as num?)?.toInt() ?? 0,
    focusedMinutes: (json['focusedMinutes'] as num?)?.toInt() ?? 0,
    completed: json['completed'] as bool? ?? false,
  );
}
