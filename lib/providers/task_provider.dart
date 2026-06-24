import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/task_log.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/services/recurrence_service.dart';
import 'dart:convert';
import 'package:life_pilot/models/subtask.dart';
import 'package:life_pilot/services/notification_service.dart';

final taskProvider = ChangeNotifierProvider<TaskNotifier>((ref) {
  return TaskNotifier();
});

class TaskNotifier extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  final NotificationService _notifService = NotificationService();
  final _uuid = Uuid();

  List<Task> _tasks = [];
  Map<String, TaskLog?> _todayLogs = {};
  final Map<String, int> _streaks = {};
  final Map<String, Set<String>> _subtaskChecks = {}; // taskId -> checked subtasks IDs
  final Map<String, int> _subtaskCounts = {}; // taskId -> checked subtasks count
  bool _isLoading = true;

  List<Task> get tasks => _tasks;
  List<Task> get activeTasks => _tasks.where((t) => t.isActive).toList();
  bool get isLoading => _isLoading;

  List<Task> getTasksDueOn(DateTime date) {
    return activeTasks.where((t) => RecurrenceService.isDueOn(t, date)).toList();
  }

  List<Task> get todayTasks => getTasksDueOn(DateTime.now());

  TaskLog? getLogForTask(String taskId) => _todayLogs[taskId];
  int getStreak(String taskId) => _streaks[taskId] ?? 0;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try{
      _tasks = await _db.getTasks();
      await _loadTodayLogs();
      await _loadStreaks();
      await _loadSubtaskCounts();
    } catch(e) {
      debugPrint('Error loading tasks: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTodayLogs() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logs = await _db.getLogsForDate(today);
    _todayLogs = {for (var log in logs) log.taskId: log};
  }

  Future<void> _loadSubtaskCounts() async {
    _subtaskCounts.clear();
    for (final task in _tasks) {
      final subtasks = await _db.getSubtasks(task.id);
      if (subtasks.isNotEmpty) {
        _subtaskCounts[task.id] = subtasks.length;
      }
    }
  }

  int getSubtaskCount(String taskId) => _subtaskCounts[taskId] ?? 0;
  int getCheckedCount(String taskId) => getCheckedSubtaskIds(taskId).length;

  Future<void> _loadStreaks() async {
    for (final task in activeTasks) {
      if(task.recurrenceType != RecurrenceType.oneTime) {
        _streaks[task.id] = await _db.getStreakForTask(task.id);
      }
    }
  }

  Future<void> addTask(Task task) async {
    await _db.insertTask(task);
    _tasks.insert(0, task);

    if(task.reminderOffsets.isNotEmpty) {
      await _notifService.scheduleForTask(task);
    }
    if(task.isAlarm) {
      await _notifService.scheduleAlarm(task);
    }

    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    final updated = task.copyWith(updatedAt: DateTime.now().toIso8601String());
    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if(idx != -1) _tasks[idx] = updated;
    await _notifService.cancelForTask(task.id);
    if(updated.reminderOffsets.isNotEmpty && updated.isActive) {
      await _notifService.scheduleForTask(updated);
    }
    if(updated.isAlarm && updated.isActive) {
      await _notifService.scheduleAlarm(updated);
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await _db.deleteTask(taskId);
    await _notifService.cancelForTask(taskId);
    _tasks.removeWhere((t) => t.id == taskId);
    _todayLogs.remove(taskId);
    _streaks.remove(taskId);
    notifyListeners();
  }

  Future<void> toggleActive(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    final updated = task.copyWith(
      isActive: !task.isActive,
      updatedAt: DateTime.now().toIso8601String()
    );

    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if(idx != -1) _tasks[idx] = updated;

    if(!updated.isActive) {
      await _notifService.cancelForTask(taskId);
    } else {
      if(updated.reminderOffsets.isNotEmpty) {
        await _notifService.scheduleForTask(updated);
      }
      if(updated.isAlarm) {
        await _notifService.scheduleAlarm(updated);
      }
    }

    notifyListeners();
  }

  Future<void> markDone(String taskId, {String? notes}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final subtaskNotes = _encodeSubtaskNotes(taskId);
    final log = TaskLog(
      id: _uuid.v4(), 
      taskId: taskId, 
      date: today, 
      status: TaskLogStatus.done,
      completedAt: DateTime.now().toIso8601String(),
      notes: notes ?? subtaskNotes,

    );
  
    await _db.deleteLogsForTaskOnDate(taskId, today);
    await _db.insertLog(log);
    _todayLogs[taskId] = log;

    _streaks[taskId] = await _db.getStreakForTask(taskId);
    notifyListeners();
  }

  Future<void> markSkipped(String taskId, {String? reason}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = TaskLog(
      id: _uuid.v4(), 
      taskId: taskId, 
      date: today, 
      status: TaskLogStatus.skipped,
      completedAt: DateTime.now().toIso8601String(),
      skipReason: reason
    );
  
    await _db.deleteLogsForTaskOnDate(taskId, today);
    await _db.insertLog(log);
    _todayLogs[taskId] = log;
    notifyListeners();
  }

  Future<void> undoLog(String taskId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _db.deleteLogsForTaskOnDate(taskId, today);
    _todayLogs.remove(taskId);
    _streaks[taskId] = await _db.getStreakForTask(taskId);
    notifyListeners();
  }

  Future<List<TaskLog>> getLogsForTask(String taskId) async {
    return await _db.getLogsForTask(taskId);
  }

  Future<int> getBestStreak(String taskId) async {
    return await _db.getBestStreakForTask(taskId);
  }

  Future<int> getTotalCompletitions(String taskId) async {
    return await _db.getTotalCompletitions(taskId);
  }

  // --Subtask --
  Future<List<Subtask>> getSubtasks(String taskId) async {
    return await _db.getSubtasks(taskId);
  }

  Future<void> saveSubtasks(String taskId, List<Subtask> subtasks) async {
    await _db.replaceSubtasks(taskId, subtasks);
  }

  /// Get checked subtask IDs for today (in-memory, resets daily)
  Set<String> getCheckedSubtaskIds(String taskId) {
    if (!_subtaskChecks.containsKey(taskId)) {
      final log = _todayLogs[taskId];
      if (log?.notes != null && log!.notes!.isNotEmpty) {
        try {
          final data = jsonDecode(log.notes!) as Map<String, dynamic>;
          final checked = data['checked'] as List<dynamic>?;
          _subtaskChecks[taskId] = checked?.map((e) => e.toString()).toSet() ?? {};
        } catch(_) {
          _subtaskChecks[taskId] = {};
        }
      } else {
        _subtaskChecks[taskId] = {};
      }
    }
    return _subtaskChecks[taskId]!;
  }

  /// Toggle a subtasks checked state for today
  void toggleSubtaskChecked(String taskId, String subtaskId) {
    final checked = getCheckedSubtaskIds(taskId);
    if (checked.contains(subtaskId)) {
      checked.remove(subtaskId);
    } else {
      checked.add(subtaskId);
    }
    notifyListeners();
  }

  /// encode checked subtasks into JSON for log notes
  String? _encodeSubtaskNotes(String taskId) {
    final checked = _subtaskChecks[taskId];
    if (checked == null || checked.isEmpty) return null;
    return jsonEncode({'checked': checked.toList()});
  }
}
