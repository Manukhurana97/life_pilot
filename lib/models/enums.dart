enum RecurrenceType {
  oneTime,
  daily,
  specificDays,
  weekly,
  biweekly,
  monthlyDate,
  monthlyOrdinal,
  quarterly,
  yearly,
  customInterval,
}

enum TaskPriority {
  low,
  medium,
  high,
}

enum TaskLogStatus {
  done,
  skipped,
  missed,
}

extension RecurrenceTypeX on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.oneTime:
        return 'One Time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.specificDays:
        return 'Specific Days';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.biweekly:
        return 'Biweekly';
      case RecurrenceType.monthlyDate:
        return 'Monthly (Date)';
      case RecurrenceType.monthlyOrdinal:
        return 'Monthly (Day)';
      case RecurrenceType.quarterly:
        return 'Quarterly';
      case RecurrenceType.yearly:
        return 'Yearly';
      case RecurrenceType.customInterval:
        return 'Custom Interval';
    }
  }
}

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
}