import 'dart:io';

import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/app.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

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