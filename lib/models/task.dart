import 'dart:convert';
import 'package:life_pilot/models/enums.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final TaskPriority priority;
  final String? startTime;
  final String? endTime;
  final RecurrenceType recurrenceType;
  final Map<String, dynamic> recurrenceDate;
  final String startDate;
  final String? endDate;
  final List<int> reminderOffsets; // in minutes
  final bool isAlarm;
  final String? alarmSound;
  final int snoozeMinutes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.priority = TaskPriority.medium,
    this.startTime,
    this.endTime,
    this.recurrenceType = RecurrenceType.oneTime,
    this.recurrenceDate = const {},
    required this.startDate,
    this.endDate,
    this.reminderOffsets = const [],
    this.isAlarm = false,
    this.alarmSound,
    this.snoozeMinutes = 5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'priority': priority.index,
      'start_time': startTime,
      'end_time': endTime,
      'recurrent_type': recurrenceType.name,
      'recurrence_date': jsonEncode(recurrenceDate),
      'start_date': startDate,
      'end_date': endDate,
      'reminder_offset': jsonEncode(reminderOffsets),
      'is_alarm': isAlarm ? 1 : 0,
      'alarm_sound': alarmSound,
      'snooze_minutes': snoozeMinutes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      priority: TaskPriority.values[map['priority'] as int? ?? 1],
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == (map['recurrent_type'] as String? ?? 'oneTime'),
        orElse: () => RecurrenceType.oneTime,
      ),  
      recurrenceDate: map['recurrence_date'] != null
          ? jsonDecode(map['recurrence_date'] as String) as Map<String, dynamic>
          : {},
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      reminderOffsets: map['reminder_offset'] != null
          ? (jsonDecode(map['reminder_offset'] as String) as List).cast<int>()
          : [],
      isAlarm: (map['is_alarm'] as int? ?? 0) == 1,
      alarmSound: map['alarm_sound'] as String?,
      snoozeMinutes: map['snooze_minutes'] as int? ?? 5,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  static const _sentinal = Object();

  Task copyWith({
    String? id,
    String? title,
    Object? description = _sentinal,
    Object? categoryId = _sentinal,
    TaskPriority? priority,
    Object? startTime = _sentinal,
    Object? endTime = _sentinal,
    RecurrenceType? recurrenceType,
    Map<String, dynamic>? recurrenceDate,
    String? startDate,
    Object? endDate = _sentinal,
    List<int>? reminderOffsets,
    bool? isAlarm,
    Object? alarmSound = _sentinal,
    int? snoozeMinutes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description == _sentinal ? this.description : description as String?,
      categoryId: categoryId == _sentinal ? this.categoryId : categoryId as String?,
      priority: priority ?? this.priority,
      startTime: startTime == _sentinal ? this.startTime : startTime as String?,
      endTime: endTime == _sentinal ? this.endTime : endTime as String?,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDate: recurrenceDate ?? this.recurrenceDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _sentinal ? this.endDate : endDate as String?,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      isAlarm: isAlarm ?? this.isAlarm,
      alarmSound: alarmSound == _sentinal ? this.alarmSound : alarmSound as String?,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}