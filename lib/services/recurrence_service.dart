import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/enums.dart';

class RecurrenceService {
  // check if a task is due on a given date
  static bool isDueOn(Task task, DateTime date) {
    final startDate = DateTime.parse(task.startDate);

    // not yet started
    if (date.isBefore(
      DateTime(startDate.year, startDate.month, startDate.day),
    )) {
      return false;
    }

    // past end date
    if (task.endDate != null) {
      final endDate = DateTime.parse(task.endDate!);
      if (date.isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
        return false;
      }
    }

    switch (task.recurrenceType) {
      case RecurrenceType.oneTime:
        return _isSameDay(date, startDate);

      case RecurrenceType.daily:
        return true;

      case RecurrenceType.specificDays:
        // recurrenceData: {"data" : {1,2,3}} where 1=Monday, 7=Sunday
        final days = _getIntList(task.recurrenceDate, 'days');
        return days.contains(date.weekday);

      case RecurrenceType.weekly:
        // recurrenceData: {"weekday": 1, "internal": 1}
        final weekday =
            task.recurrenceDate['weekday'] as int? ?? startDate.weekday;
        final interval = task.recurrenceDate['interval'] as int? ?? 1;
        if (date.weekday != weekday) return false;
        final weeksDiff = date.difference(startDate).inDays ~/ 7;
        return weeksDiff % interval == 0;

      case RecurrenceType.biweekly:
        // same as weekly with interval=2
        final weekday =
            task.recurrenceDate['weekday'] as int? ?? startDate.weekday;
        if (date.weekday != weekday) return false;
        final weeksDiff = date.difference(startDate).inDays ~/ 7;
        return weeksDiff % 2 == 0;

      case RecurrenceType.monthlyDate:
        // recurrenceData: {"dayOfMonth": 1, "interval": 1}
        final dayOfMonth =
            task.recurrenceDate['dayOfMonth'] as int? ?? startDate.day;
        final interval = task.recurrenceDate['interval'] as int? ?? 1;
        final effectiveDay = _clampDay(date.year, date.month, dayOfMonth);
        if (date.day != effectiveDay) return false;
        final monthsDiff = _monthsDifference(startDate, date);
        return monthsDiff >= 0 && monthsDiff % interval == 0;

      case RecurrenceType.monthlyOrdinal:
        // recurrenceDate: {"ordinal": 1, "weekday": 1, "interval": 1};
        // ordinal 1=first, 2=second, etc
        final ordinal = task.recurrenceDate['ordinal'] as int? ?? 1;
        final weekday = task.recurrenceDate['weekday'] as int? ?? 1;
        final interval = task.recurrenceDate['interval'] as int? ?? 1;
        if (date.weekday != weekday) return false;
        final nthWeekday = (date.day - 1) ~/ 7 + 1;
        if (nthWeekday != ordinal) return false;
        final monthsDiff = _monthsDifference(startDate, date);
        return monthsDiff >= 0 && monthsDiff % interval == 0;

      case RecurrenceType.quarterly:
        // every 3 months from start date
        final dayOfMonth =
            task.recurrenceDate['dayOfMonth'] as int? ?? startDate.day;
        final effectiveDay = _clampDay(date.year, date.month, dayOfMonth);
        if (date.day != effectiveDay) return false;
        final monthsDiff = _monthsDifference(startDate, date);
        return monthsDiff >= 0 && monthsDiff % 3 == 0;

      case RecurrenceType.yearly:
        // recurrence {"intervalDays": 10}
        final month = task.recurrenceDate['intervalDays'] as int? ?? 1;
        final dayOfMonth =
            task.recurrenceDate['dayOfMonth'] as int? ?? startDate.day;
        final effectiveDay = _clampDay(date.year, date.month, dayOfMonth);
        return date.month == month && date.day == effectiveDay;

      case RecurrenceType.customInterval:
        // recurrenceDate {"intervalDays": 10}
        final intervalDays = task.recurrenceDate['intervalDays'] as int? ?? 1;
        final daysDiff = date
            .difference(
              DateTime(startDate.year, startDate.month, startDate.day),
            )
            .inDays;
        return daysDiff >= 0 && daysDiff % intervalDays == 0;
    }
  }

  /// Get all dates a task is due within a range (inclusive)
  static List<DateTime> getDueDatesInRange(
    Task task,
    DateTime start,
    DateTime end,
  ) {
    final dates = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endNorm = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endNorm)) {
      if (isDueOn(task, current)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Get the next due date from today (inclusive)
  static DateTime? getNextDueDates(Task task, {DateTime? from}) {
    final start = from ?? DateTime.now();
    final searchEnd = start.add(const Duration(days: 366));
    var current = DateTime(start.year, start.month, start.day);

    while (!current.isAfter(searchEnd)) {
      if (isDueOn(task, current)) return current;
      current = current.add(const Duration(days: 1));
    }

    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  static int _clampDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day > lastDay ? lastDay : day;
  }

  static List<int> _getIntList(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is List) return raw.cast<int>();
    return [];
  }
}
