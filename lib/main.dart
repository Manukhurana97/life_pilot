import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/app.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Create a container to pre-load settings
  final container = ProviderContainer();
  await container.read(settingsProvider).loadSettings();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LifePilotApp(),
    )
  );
}