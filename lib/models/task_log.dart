import 'package:life_pilot/models/enums.dart';

class TaskLog {
  final String id;
  final String taskId;
  final String date;
  final TaskLogStatus status;
  final String? completedAt;
  final String? skipReason;
  final String? notes;

  TaskLog({
    required this.id,
    required this.taskId,
    required this.date,
    required this.status,
    this.completedAt,
    this.skipReason,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'date': date,
      'status': status.name,
      'completed_at': completedAt,
      'skip_reason': skipReason,
      'notes': notes,
    };
  }

  factory TaskLog.fromMap(Map<String, dynamic> map) {
    return TaskLog(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      date: map['date'] as String,
      status: TaskLogStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => TaskLogStatus.missed,
      ),
      completedAt: map['completed_at'] as String?,
      skipReason: map['skip_reason'] as String?,
      notes: map['notes'] as String?,
    );
  }
}