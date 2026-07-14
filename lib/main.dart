import 'dart:io';

import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/app.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize alarm manager (must be before notification init
  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  // Initialize notifications
  await initializeDateFormatting();
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Listen for iOS BGTaskScheduler reschedule requests
  if (Platform.isIOS) {
    const bgChannel = MethodChannel('com.mk.life_pilot/bg_task');
    bgChannel.setMethodCallHandler((call) async {
      if (call.method == 'rescheduleFromBackground') {
        debugPrint('[BGTask] Received rescheduleFromBackground from iOS');
        final db = AppDatabase();
        final taskMaps = await (await db.database).query('tasks');
        final tasks = taskMaps.map((m) => Task.fromMap(m)).toList();
        await NotificationService().rescheduleAllTasks(tasks);
        debugPrint('[BGTask] background reschedule complete');
        return true;
      }
      return null;
    });
  }

  // Create a container to pre-load settings
  final container = ProviderContainer();
  await container.read(settingsProvider).loadSettings();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DayPilotApp(),
    )
  );
}