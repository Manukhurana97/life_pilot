import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/screens/alarm/alarm_screen.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/services/recurrence_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Global navigator key - set this in MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Pending alarm payloads (received before navigator is ready)
  static String? _pendingAlarmPayload;

  Future<void> initialize() async {
    if(_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tag - navigate to task detail
    // payload contains taskId

    final payload = response.payload;
    if (payload == null) return;

    if(payload.startsWith("alarm_")) {
      final _ = payload.replaceFirst('alarm_', '');
      final navigator = navigatorKey.currentState;
      if(navigator != null) {
        navigator.push(
            MaterialPageRoute(
                builder: (_) => AlarmScreen(
                    taskTitle: 'Alarm',
                  alarmSoundId: null, // Will be resolved by AlarmScreen
                ),
            ),
        );
      } else {
        _pendingAlarmPayload = payload;
      }
    }
  }

  /// Call this from app startup to handle any pending alarm
  void handlePendingAlarm() {
    if (_pendingAlarmPayload != null) {
      _onNotificationTap(NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
        payload: _pendingAlarmPayload,
      ));
      _pendingAlarmPayload = null;
    }
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if(android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if(ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Schedule notifications for a task for the next 7 days
  Future<void> scheduleForTask(Task task) async {
    if(task.reminderOffsets.isEmpty || !task.isActive) return;

    // Cancel existing notifications for a task for the next 7 days
    await cancelForTask(task.id);

    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final dueDates = RecurrenceService.getDueDatesInRange(task, now, end);

    // use a better spread to reduce collision risk between tasks
    int notifId = (task.id.hashCode & 0x7FFFFFFF) % 2000000;

    for (final dueDate in dueDates) {
      for (final offsetMinutes in task.reminderOffsets) {
        DateTime taskTime;
        if(task.startTime != null) {
          final parts = task.startTime!.split(':');
          taskTime = DateTime(
            dueDate.year, dueDate.month, dueDate.day,
            int.parse(parts[0]), int.parse(parts[1]),
          );
        } else {
          taskTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
        }

        final notifTime = taskTime.subtract(Duration(minutes: offsetMinutes));
        if(notifTime.isBefore(now)) continue;

        final tzTime = tz.TZDateTime.from(notifTime, tz.local);

        String body = task.description ?? '';
        if(offsetMinutes > 0) {
          body = 'Starting in $offsetMinutes minutes${body.isNotEmpty ? ' - $body' : ''}';
        }

        await _plugin.zonedSchedule(
          id: notifId++,
          title: task.title,
          body: body.isEmpty ? null : body,
          scheduledDate: tzTime,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails (
              'task_reminders', 
              'Task Reminders',
              channelDescription: 'Reminders for your scheduled tasks',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            )
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id
        );
      }
    } 
  }

  /// Schedule alarm notification (full-screen intent on Android)
  Future<void> scheduleAlarm(Task task) async {
    if(!task.isAlarm || !task.isActive) return;

    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final dueDates = RecurrenceService.getDueDatesInRange(task, now, end);

    debugPrint('[ALARM] scheduleAlarm for "${task.title}" isAlarm=${task.isAlarm} startTime=${task.startTime} sound=${task.alarmSound} dueDate=${dueDates.length}');
    int notifId = ((task.id.hashCode & 0x7FFFFFFF) % 2000000) + 2000000;

    for (final dueDate in dueDates) {
      DateTime alarmTime;
      if (task.startTime != null) {
        final parts = task.startTime!.split(':');
        alarmTime = DateTime(
          dueDate.year, dueDate.month, dueDate.day,
          int.parse(parts[0]), int.parse(parts[1]),
        );
      } else {
        continue; // Alarm needs a time
      }

      if (alarmTime.isBefore(now)) {
        // Grace window: if alarm time just passed (within 5 min), schedule for 5s from now
        final diff = now.difference(alarmTime).inSeconds;
        if (diff <= 300) {
          debugPrint('[ALARM] alarm at $alarmTime just alarm (${diff}s ago) scheduling for now + 5s');
          alarmTime = now.add(const Duration(seconds: 5));
        } else {
          debugPrint('[ALARM] skipping past alarm: $alarmTime');
          continue;
        }
      }

      debugPrint('[ALARM] Scheduling alarm at $alarmTime (notifId=$notifId)');
      final tzTime = tz.TZDateTime.from(alarmTime, tz.local);

      try {
        await _plugin.zonedSchedule(
          id: notifId++,
          title: '⏰ ${task.title}',
          body: task.description,
          scheduledDate: tzTime,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'alarms',
              'Alarms',
              channelDescription: 'Alarm notifications',
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              sound: task.alarmSound != null && !task.alarmSound!.startsWith('custom_')
                  ? RawResourceAndroidNotificationSound(task.alarmSound!)
                  : null,
              playSound: true,
              enableVibration: true,
              ongoing: true,
              autoCancel: false,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'alarm_${task.id}',
        );
        debugPrint('[ALARM] Alarm scheduled successfully');
      } catch (e) {
        debugPrint('[ALARM] exact alarm failed: $e - failing back to inexact');

        await _plugin.zonedSchedule(
          id: notifId,
          title: '⏰ ${task.title}',
          body: task.description,
          scheduledDate: tzTime,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'alarms',
              'Alarms',
              channelDescription: 'Alarm notifications',
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              playSound: true,
              enableVibration: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'alarm_${task.id}',
        );
        debugPrint('[ALARM] Alarm scheduled (inexact fallback)');
      }
    }
  }

  Future<void> cancelForTask(String taskId) async {
    // Cancel a range of notification IDs derived from the task
    final baseId = (taskId.hashCode & 0x7FFFFFFF) % 2000000;
    for (int i = 0; i < 50; i++) {
      await _plugin.cancel(id: baseId + i);
    }
    final alarmBase = baseId + 2000000;
    for (int i=0; i < 20; i++) {
      await _plugin.cancel(id: alarmBase + i);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Re-schedule all active task (call on app start or task change)
  Future<void> rescheduleAllTasks(List<Task> tasks) async {
    await cancelAll();
    for (final task in tasks) {
      if (!task.isActive) continue;
      if (task.reminderOffsets.isNotEmpty) {
        await scheduleForTask(task);
      }

      if (task.isAlarm) {
        await scheduleAlarm(task);
      }
    }
  }
}