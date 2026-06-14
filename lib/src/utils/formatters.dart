import 'package:intl/intl.dart';

/// Display formatting helpers for durations and dates.
class Formatters {
  Formatters._();

  /// 135 -> "2h 15m", 45 -> "45m", 120 -> "2h".
  static String duration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// 135 -> "2.3h".
  static String hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)}h';

  /// 0 -> "12am", 9 -> "9am", 13 -> "1pm", 23 -> "11pm".
  static String hourLabel(int hour) {
    final h = hour % 24;
    if (h == 0) return '12am';
    if (h == 12) return '12pm';
    if (h < 12) return '${h}am';
    return '${h - 12}pm';
  }

  static String weekday(DateTime date) => DateFormat('EEE').format(date);

  static String shortDate(DateTime date) => DateFormat('MMM d').format(date);

  static String longDate(DateTime date) =>
      DateFormat('EEEE, MMMM d').format(date);

  static String time(DateTime date) => DateFormat('h:mm a').format(date);

  /// "Today", "Yesterday", or a short date.
  static String relativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return '$diff days ago';
    return shortDate(date);
  }

  /// A friendly greeting based on the current hour.
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
