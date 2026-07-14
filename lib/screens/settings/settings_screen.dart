import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/services/backup_service.dart';
import 'package:life_pilot/services/battery_optimization_service.dart';
import 'package:life_pilot/services/notification_service.dart';
import 'package:life_pilot/core/constraints/app_constraints.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance
          _sectionHeader(theme, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref),
          ),

          const Divider(),
          _sectionHeader(theme, 'Tasks'),
          SwitchListTile(
            secondary: const Icon(Icons.check_circle_outline),
            title: const Text('Show complete tasks'),
            subtitle: const Text('Show done tasks on home screen'),
            value: settings.showCompletedTasks,
            onChanged: (v) => ref.read(settingsProvider).setShowCompleted(v),
          ),
          ListTile(
            leading: const Icon(Icons.snooze),
            title: const Text('Default snooze'),
            subtitle: Text('${settings.defaultSnoozeMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSnoozeDialog(context, ref),
          ),

          const Divider(),
          _sectionHeader(theme, 'Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Request permissions'),
            subtitle: const Text('Enable notifications & alarms'),
            onTap: () async {
              await NotificationService().requestPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification permissions requested')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reschedule all'),
            subtitle: const Text('Re-sync all task notifications'),
            onTap: () async {
              final tasks = ref.read(taskProvider).tasks;
              await NotificationService().rescheduleAllTasks(tasks);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications reschedule')),
                );
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Battery optimization'),
            subtitle: const Text('Ensure alarms work when app is closed'),
            onTap: () => BatteryOptimizationService.checkAndPrompt(context, force: true),
          ),

          const Divider(),
          _sectionHeader(theme, 'Data'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Data'),
            subtitle: const Text('Save all tasks and logs to a backup file'),
            onTap: () => _handleExport(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import data'),
            subtitle: const Text('Restore from a backup file'),
            onTap: () => _handleImport(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            title: Text('Reset everything', style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text('Delete all tasks, logs & settings'),
            onTap: () => _showResetConfirmation(context, ref),
          ),

          const Divider(),
          _sectionHeader(theme, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppConstants.appName),
            subtitle: Text('Version ${AppConstants.appVersion}'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).themeMode;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('choose Theme'),
        children: ThemeMode.values.map((mode) {
          return ListTile(
            title: Text(_themeModeLabel(mode)),
            leading: Icon(
              mode == current ? Icons.radio_button_checked : Icons.radio_button_off,
              color: mode == current ? Theme.of(ctx).colorScheme.primary : null,
            ),
            onTap: () {
              ref.read(settingsProvider).setThemeMode(mode);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      )
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              size: 48, color: Theme.of(ctx).colorScheme.error),
          title: const Text('Reset everything?'),
          content: const Text(
            'This will permanently delete all your tasks, logs, categories '
                'and settings. Default categories will be restored.\n\n'
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AppDatabase().resetAll();
                await NotificationService().cancelAll();
                await ref.read(settingsProvider).resetAll();
                await ref.read(taskProvider).loadTasks();
                await ref.read(categoryProvider).loadCategories();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All data has been reset'))
                  );
                }
              },
              child: const Text('Reset'),
            )
          ],
        )
    );
  }

  void _handleExport(BuildContext context) async {
    try {
      final path = await BackupService().exportDate();
      if (!context.mounted) return;

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Backup Saved!'),
            content: SelectableText(
              'File saved to:\n\n$path\n\nYou can find this file using your file manager app.',
            ),
            actions: [
              if (Platform.isAndroid) 
                TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openFileLocation(path);
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text("Open Folder")
                ),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
              )
            ]
          )
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
  
  void _openFileLocation(String filePath) {
    try {
      const channel = MethodChannel("com.mk.life_pilot/file");
      channel.invokeMethod('openFileLocation', {'path': filePath});
    } catch (e) {
      debugPrint('[BACKUP] Failed to open file location: $e');
    }
  }

  void _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = BackupService();
      final data = await backupService.pickBackupFile();
      if (data == null) return;

      final summary = backupService.getBackupSummary(data);
      final exportAt = data['exportAt'] as String?;

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.download, size: 48),
            title: const Text('Import backup?'),
            content: Text(
              '${exportAt != null ? 'Backup from ${_formatDate(exportAt)}\n\n': ''}'
                  'This file contains: \n'
                  '• ${summary['tasks']} tasks\n'
                  '• ${summary['categories']} categories\n'
                  '• ${summary['logs']} task logs\n'
                  '• ${summary['subtasks']} subtasks logs\n'
                  'This will replace all your current data'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Import')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
            ],
          )
      );

      if (confirmed != true || !context.mounted)  return;

      await backupService.importData(data);
      await ref.read(taskProvider).loadTasks();
      await ref.read(categoryProvider).loadCategories();

      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${summary['tasks']} tasks successfully'))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import Failed: $e'))
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _showSnoozeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).defaultSnoozeMinutes;
    showDialog(
      context: context, 
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Snooze'),
        children: [5, 10, 15, 30].map((minutes) {
          return ListTile(
            title: Text('$minutes minutes'),
            leading: Icon(
              minutes == current ? Icons.radio_button_checked : Icons.radio_button_off,
              color: minutes == current ? Theme.of(ctx).colorScheme.primary : null,
            ),
            onTap: () {
              ref.read(settingsProvider).setDefaultSnooze(minutes);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      )
    );
  }
}