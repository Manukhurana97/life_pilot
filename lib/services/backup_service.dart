import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:sqflite/sqlite_api.dart';

class BackupService {
  final AppDatabase _db = AppDatabase();

  /// Export all data to Json and save to external storage
  /// Returns the file path where the backups was saved
  Future<String> exportDate() async {
    final db = await _db.database;

    final categories = await db.query('categories');
    final tasks = await db.query('tasks');
    final taskLogs = await db.query('taskLogs');
    final subtasks = await db.query('subtasks');

    final data = {
      'version': 1,
      'app': 'DayPilot',
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories,
      'tasks': tasks,
      'taskLogs': taskLogs,
      'subtasks': subtasks
    };

    final jsonStr = const JsonEncoder.withIndent(' ').convert(data);

    // Use external storage (user-accessible via file-manager)
    Directory dir;
    try {
      final extDir = await getExternalStorageDirectories();
      dir = extDir ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/daypilot_backup_$timestamp.json');
    await file.writeAsString(jsonStr);

    debugPrint('[BACKUP] Exported to ${file.path}');
    return file.path;
  }

  /// Pick a JSON backup file and return its parsed content
  Future<Map<String, dynamic>?> pickBackupFile() async {
    const typeGroup = XTypeGroup(
      label: 'JSON backup',
      extensions: ['JSON'],
      mimeTypes: ['application/json'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;

    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    if (!data.containsKey('tasks') || !data.containsKey('categories')) {
      throw const FormatException('Invalid backup file: missing tasks or categories');
    }

    return data;
  }

  /// Get a summary of what's in the backup
  Map<String, int> getBackupSummary(Map<String, dynamic> data) {
    return {
      'tasks': (data['tasks'] as List?)?.length ?? 0,
      'categories': (data['categories'] as List?)?.length ?? 0,
      'logs': (data['logs'] as List?)?.length ?? 0,
      'subtasks': (data['subtasks'] as List?)?.length ?? 0,
    };
  }

  /// Import data from parsed JSON, replacing all existing data
  Future<void> importData(Map<String, dynamic> data) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // Clear all existing data
      await txn.delete('subtasks');
      await txn.delete('task_logs');
      await txn.delete('tasks');
      await txn.delete('categories');

      // Import categories
      for (final item in (data['categories'] as List?) ?? []) {
        await txn.insert('categories', Map<String, dynamic>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Import tasks
      for (final item in (data['tasks'] as List?) ?? []) {
        await txn.insert('tasks', Map<String, dynamic>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Import taskLogs
      for (final item in (data['taskLogs'] as List?) ?? []) {
        await txn.insert('task_logs', Map<String, dynamic>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Import subtasks
      for (final item in (data['subtasks'] as List?) ?? []) {
        await txn.insert('subtasks', Map<String, dynamic>.from(item), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    debugPrint('[BACKUP] Import complete');
  }
}