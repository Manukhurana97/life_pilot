import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = ChangeNotifierProvider<SettingsNotifier>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showCompletedTasks = true;
  int _defaultSnoozeMinutes = 5;

  ThemeMode get themeMode => _themeMode;
  bool get showCompletedTasks => _showCompletedTasks;
  int get defaultSnoozeMinutes => _defaultSnoozeMinutes;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    _showCompletedTasks = prefs.getBool('showCompleted') ?? true;
    _defaultSnoozeMinutes = prefs.getInt('snoozeMinutes') ?? 5;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setShowCompleted(bool value) async {
    _showCompletedTasks = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showCompleted', value);
    notifyListeners();
  }

  Future<void> setDefaultSnooze(int minutes) async {
    _defaultSnoozeMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snoozeMinutes', minutes);
    notifyListeners();
  }
}
