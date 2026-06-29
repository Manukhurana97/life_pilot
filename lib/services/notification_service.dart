import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/screens/alarm/alarm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/services/recurrence_service.dart';

/// Top-level callback for android_alarm_manager.dart
/// Runs in a separate isolate - must re-initialize everything.
@pragma('vm:entry-point')
Future<void> alarmManagerCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[ALARM] Callback fired for id=$id');

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final title = prefs.getString('alarm_${id}_title') ?? 'Alarm';
  final body = prefs.getString('alarm_${id}_body');
  final sound = prefs.getString('alarm_${id}_sound');
  final taskId = prefs.getString('alarm_${id}_taskId') ?? '';
  final snoozeMin = prefs.getInt('alarm_${id}_snoozeMinutes') ?? 5;

  debugPrint(
    '[ALARM] title=$title sound=$sound taskId=$taskId snoozeMin=$snoozeMin',
  );

  // Store active alarm date so snooze handler can re-use it
  await prefs.setString('active_alarm_${id}_title', title);
  if (body != null) await prefs.setString('active_alarm_${id}_body', body);
  if (sound != null) await prefs.setString('active_alarm_${id}_sound', sound);
  await prefs.setString('active_alarm_${id}_taskId', taskId);
  await prefs.setInt('active_alarm_${id}_snoozeMinutes', snoozeMin);

  // Initialize a fresh plugin instance in this isolate
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Show an IMMEDIATE notification with Dismiss/Snooze action buttons
  await plugin.show(
    id: id,
    title: '⏰ $title',
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_v2',
        'Alarms',
        channelDescription: 'Alarm notifications',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        sound: sound != null && !sound.startsWith('custom_')
            ? RawResourceAndroidNotificationSound(sound)
            : null,
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
        actions: [
          const AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze',
            'Snooze ($snoozeMin min)',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    ),
    payload: 'alarm_$taskId',
  );

  debugPrint('[ALARM-BG] Notification shown with Dismiss/Snooze actions');

  // start a pending alarm flag so the foreground app can detect it and show AlarmScreen
  await prefs.setString('pending_alarm_title', title);
  await prefs.setString('pending_alarm_body', body ?? '');
  await prefs.setString('pending_alarm_sound', sound ?? '');
  await prefs.setString('pending_alarm_taskId', taskId);
  await prefs.setInt('pending_alarm_snoozeMinutes', snoozeMin);
  await prefs.setInt('pending_alarm_notifId', id);
  await prefs.setInt('pending_alarm_timestamp', DateTime.now().millisecondsSinceEpoch);

  // Cleanup scheduling metadata (active alarm metadata kept for snooze)
  await prefs.remove('alarm_${id}_title');
  await prefs.remove('alarm_${id}_body');
  await prefs.remove('alarm_${id}_sound');
  await prefs.remove('alarm_${id}_taskId');
  await prefs.remove('alarm_${id}_snoozeMinutes');
}

/// Top-level callback for reminder notifications via AndroidAlarmManager.
/// Runs in a separate isolate - show a simple notification (no snooze / dismiss).
@pragma('vm:entry-point')
Future<void> reminderCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[REMINDER] Callback fired for id=$id');

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final title = prefs.getString('reminder_${id}_title') ?? 'Reminder';
  final body = prefs.getString('reminder_${id}_body');
  final taskId = prefs.getString('reminder_${id}_taskId');

  debugPrint('[REMINDER] title=$title body=$body taskId=$taskId');

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Reminders for your scheduled tasks',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: taskId,
  );

  debugPrint('[REMINDER] Notification shown');

  // Cleanup
  await prefs.remove('reminder_${id}_title');
  await prefs.remove('reminder_${id}_body');
  await prefs.remove('reminder_${id}_taskId');
}

/// Top level handler for notification actions when app is in background/killed.
/// Handles Dismiss and Snooze button button taps from the notification.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = response.actionId;
  final id = response.id;

  debugPrint('[ALARM-ACTION] Background action=$actionId notificationId=$id');

  if (id == null) return;

  final prefs = await SharedPreferences.getInstance();

  if (actionId == 'snooze') {
    // Read stored alarm metadata
    final title = prefs.getString('active_alarm_${id}_title') ?? 'Alarm';
    final body = prefs.getString('active_alarm_${id}_body');
    final sound = prefs.getString('active_alarm_${id}_sound');
    final taskId = prefs.getString('active_alarm_${id}_taskId') ?? '';
    final snoozeMin = prefs.getInt('active_alarm_${id}_snoozeMinutes') ?? 5;

    // Schedule a new alarm 5 minutes from now
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMin));
    final snoozeId = id + 100000;

    // Store metadata for the snooze alarm callback
    await prefs.setString('alarm_${snoozeId}_title', title);
    if (body != null) await prefs.setString('alarm_${snoozeId}_body', body);
    if (sound != null) await prefs.setString('alarm_${snoozeId}_sound', sound);
    await prefs.setString('alarm_${snoozeId}_taskId', taskId);
    await prefs.setInt('alarm_${snoozeId}_snoozeMinutes', snoozeMin);

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        snoozeId,
        alarmManagerCallback,
        alarmClock: true,
      );
    } else {
      tz_data.initializeTimeZones();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(),
        ),
      );
      final scheduledDate = tz.TZDateTime.from(snoozeTime, tz.local);
      await plugin.zonedSchedule(
        id: snoozeId,
        title: '⏰ title',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'alarm_$taskId',
      );
    }

    debugPrint(
      '[ALARM-ACTION] Snoozed: new alarm at $snoozeTime (id=$snoozeId)',
    );
  }

  // Clean up active alarm metadata
  await prefs.remove('active_alarm_${id}_title');
  await prefs.remove('active_alarm_${id}_body');
  await prefs.remove('active_alarm_${id}_sound');
  await prefs.remove('active_alarm_${id}_taskId');
  await prefs.remove('active_alarm_${id}_snoozeMinutes');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Global navigator key - set this in MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Pending alarm payloads (received before navigator is ready)
  static String? _pendingAlarmPayload;

  /// Time for polling pending alarm from background isolate
  Timer? _alarmPollTimer;

  /// Whether we are currently showing an alarm screen (prevent duplicate)
  bool _isShowingAlarmScreen = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) async{
    final actionId = response.actionId;
    final id = response.id;
    final payload = response.payload;

    // Handle action buttons is foreground
    if (actionId == 'dismiss') {
      if (id != null) _plugin.cancel(id: id);
      await _clearPendingAlarm();
      return;
    }
    if (actionId == 'snooze') {
      if (id != null) _plugin.cancel(id: id);
      _handleSnooze(id);
      await _clearPendingAlarm();
      return;
    }

    if (payload == null) return;

    if (payload.startsWith('alarm_')) {
      if (id != null) {
        _plugin.cancel(id: id);
        _cleanupActiveAlarm(id);
      }

      // Read stored alarm metadata for the Alarm Screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final title = prefs.getString('pending_alarm_title') ?? 'Alarm';
      final description = prefs.getString('pending_alarm_body');
      final sound = prefs.getString('pending_alarm_sound') ;
      final snoozeMin = prefs.getInt('pending_alarm_snoozeMinutes') ?? 5;
      final taskId = prefs.getString('pending_alarm_taskId') ?? '';

      await _clearPendingAlarm();
      _showAlarmScreen(
        title: title,
        description: description,
        soundId: sound,
        snoozeMinutes: snoozeMin,
        taskId: taskId,
      );
    }
  }

  /// Show the full-screen Alarm Screen with sound + vibration
  void _showAlarmScreen({
    required String title,
    String? description,
    String? soundId,
    int snoozeMinutes = 5,
    String taskId = '',
}) {
    if (_isShowingAlarmScreen) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingAlarmPayload = 'alarm_$taskId';
      return;
    }
    _isShowingAlarmScreen = true;
    navigator.push(
      MaterialPageRoute(
          builder: (_) => AlarmScreen(
            taskTitle: title,
            taskDescription: description,
            alarmSoundId: soundId?.isNotEmpty == true ? soundId : null,
            snoozeMinutes: snoozeMinutes,
          ),
      ),
    ).then((result) {
      _isShowingAlarmScreen = false;
      if (result == 'snooze') {
        _handleSnoozeFromScreen(title, description, soundId, taskId, snoozeMinutes);
      }
    });
  }

  /// Handle snooze triggered from the AlarmScreen UI
  Future<void> _handleSnoozeFromScreen(
      String title, String? body, String? sound, String taskId, int snoozeMin
      ) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMin));
    final snoozeId = (taskId.hashCode & 0x7FFFFFF) % 2000000 + 40000000;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_${snoozeId}_title', title);
    if (body != null && body.isNotEmpty) await prefs.setString('alarm_${snoozeId}_body', body);
    if (sound != null && sound.isNotEmpty) await prefs.setString('alarm_${snoozeId}_sound', sound);
    await prefs.setString('alarm_${snoozeId}_taskId', taskId);
    await prefs.setInt('alarm_${snoozeId}_snoozeMinutes', snoozeMin);

    await prefs.setString('active_alarm_${snoozeId}_title', title);
    if( body != null && body.isNotEmpty) await prefs.setString('active_alarm_${snoozeId}_body', body);
    if( sound != null && sound.isNotEmpty) await prefs.setString('active_alarm_${snoozeId}_sound', sound);
    await prefs.setString('active_alarm_${snoozeId}_taskId', taskId);
    await prefs.setInt('active_alarm_${snoozeId}_snoozeMinutes', snoozeMin);

    if(Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(snoozeTime, snoozeId, alarmManagerCallback, alarmClock: true);
    } else {
      final scheduledDate = tz.TZDateTime.from(snoozeTime, tz.local);
      await _plugin.zonedSchedule(
          id: snoozeId,
          title: '⏰ $title',
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'alarm_$taskId',
      );
    }
    debugPrint('[ALARM] Snoozed from screen ($snoozeMin min)L new alarm at $snoozeTime (id=$snoozeId)');
  }

  Future<void> _handleSnooze(int? id) async {
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('active_alarm_${id}_title') ?? 'Alarm';
    final body = prefs.getString('active_alarm_${id}_body');
    final sound = prefs.getString('active_alarm_${id}_sound');
    final taskId = prefs.getString('active_alarm_${id}_taskId') ?? '';

    final snoozeMin = prefs.getInt('active_alarm_${id}_snoozeMinutes') ?? 5;
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMin));
    final snoozeId = id + 100000;

    await prefs.setString('alarm_${snoozeId}_title', title);
    if (body != null) await prefs.setString('alarm_${snoozeId}_body', body);
    if (sound != null) await prefs.setString('alarm_${snoozeId}_sound', sound);
    await prefs.setString('alarm_${snoozeId}_taskId', taskId);
    await prefs.setInt('alarm_${snoozeId}_snoozeMinutes', snoozeMin);

    if (Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        snoozeId,
        alarmManagerCallback,
        alarmClock: true,
      );
    } else {
      final scheduledDate = tz.TZDateTime.from(snoozeTime, tz.local);
      await _plugin.zonedSchedule(
        id: snoozeId,
        title: '⏰ $title',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'alarm_$title',
      );
    }

    debugPrint(
      '[ALARM] Snoozed ($snoozeMin min): new alarm at $snoozeTime (id=$snoozeId)',
    );
    _cleanupActiveAlarm(id);
  }

  Future<void> _cleanupActiveAlarm(int? id) async {
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_alarm_${id}_title');
    await prefs.remove('active_alarm_${id}_body');
    await prefs.remove('active_alarm_${id}_sound');
    await prefs.remove('active_alarm_${id}_taskId');
    await prefs.remove('active_alarm_${id}_snoozeMinutes');
  }

  /// Start polling for pending alarms from the background isolate
  /// Call this when the app shell is ready (navigator available)
  void startAlarmPolling() {
    _alarmPollTimer?.cancel();
    _alarmPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkPendingAlarm()
    );
    _checkPendingAlarm();
  }

  /// Stop polling (call in dispose)
  void stopAlarmPolling() {
    _alarmPollTimer?.cancel();
    _alarmPollTimer = null;
  }

  /// Check SharedPreference for a pending alarm from the background isolate
  Future<void> _checkPendingAlarm() async {
    if (_isShowingAlarmScreen) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final title = prefs.getString('pending_alarm_title');
    if (title == null) return;

    final timestamp = prefs.getInt('pending_alarm_timestamp') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 5 * 60 * 1000) {
      await _clearPendingAlarm();
      return;
    }

    final description = prefs.getString('pending_alarm_body');
    final sound = prefs.getString('pending_alarm_sound');
    final snoozeMin = prefs.getInt('pending_alarm_snoozeMinutes') ?? 5;
    final taskId = prefs.getString('pending_alarm_taskId') ?? '';
    final notifId = prefs.getInt('pending_alarm_notifId');

    debugPrint('[ALARM] Pending alarm detected: $title');

    await _clearPendingAlarm();

    if(notifId != null) {
      await _plugin.cancel(id: notifId);
    }

    _showAlarmScreen(
      title: title,
      description: description?.isNotEmpty == true ? description : null,
      soundId: sound,
      snoozeMinutes: snoozeMin,
      taskId: taskId,
    );
  }

  /// Clear pending alarm data from SharedPreference
  Future<void> _clearPendingAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_alarm_title');
    await prefs.remove('pending_alarm_body');
    await prefs.remove('pending_alarm_sound');
    await prefs.remove('pending_alarm_taskId');
    await prefs.remove('pending_alarm_snoozeMinutes');
    await prefs.remove('pending_alarm_notifId');
    await prefs.remove('pending_alarm_timestamp');
  }

  /// Call this from app startup to handle any pending alarm
  void handlePendingAlarm() {
    if (_pendingAlarmPayload != null) {
      _onNotificationTap(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: _pendingAlarmPayload,
        ),
      );
      _pendingAlarmPayload = null;
    }
  }

  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      final canExact = await android.canScheduleExactNotifications();
      debugPrint('[ALARM] canScheduleExactNotifications=$canExact');
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Schedule notifications for a task for the next 7 days
  Future<void> scheduleForTask(Task task) async {
    if (task.reminderOffsets.isEmpty || !task.isActive) return;

    // Cancel existing notifications for a task for the next 7 days
    await cancelForTask(task.id);

    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final dueDates = RecurrenceService.getDueDatesInRange(task, now, end);

    // use a better spread to reduce collision risk between tasks
    int notifId = (task.id.hashCode & 0x7FFFFFFF) % 2000000;

    final prefs = await SharedPreferences.getInstance();

    for (final dueDate in dueDates) {
      for (final offsetMinutes in task.reminderOffsets) {
        DateTime taskTime;
        if (task.startTime != null) {
          final parts = task.startTime!.split(':');
          taskTime = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        } else {
          taskTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
        }

        final notifTime = taskTime.subtract(Duration(minutes: offsetMinutes));
        if (notifTime.isBefore(now)) continue;

        String body = task.description ?? '';
        if (offsetMinutes > 0) {
          body =
              'Starting in $offsetMinutes minutes${body.isNotEmpty ? ' - $body' : ''}';
        }

        final currentId = notifId++;

        // store reminder metadata for the background callback
        await prefs.setString('reminder_${currentId}_title', task.title);
        if (body.isNotEmpty) {
          await prefs.setString('reminder_${currentId}_body', body);
        }
        await prefs.setString('reminder_${currentId}_taskId', task.id);

        debugPrint(
          '[REMINDER] Scheduling reminder at $notifTime (id=$currentId, offset=${offsetMinutes}min)',
        );

        if (Platform.isAndroid) {
          await AndroidAlarmManager.oneShotAt(
            notifTime,
            currentId,
            reminderCallback,
            alarmClock: true,
            rescheduleOnReboot: true,
          );
        } else {
          final scheduledDate = tz.TZDateTime.from(notifTime, tz.local);
          await _plugin.zonedSchedule(
            id: currentId,
            title: task.title,
            body: body.isNotEmpty ? body : null,
            scheduledDate: scheduledDate,
            notificationDetails: const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: task.id,
          );
        }
      }
    }
  }

  /// Schedule alarm notification
  Future<void> scheduleAlarm(Task task) async {
    if (!task.isAlarm || !task.isActive) return;

    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final dueDates = RecurrenceService.getDueDatesInRange(task, now, end);

    debugPrint(
      '[ALARM] scheduleAlarm for "${task.title}" isAlarm=${task.isAlarm} startTime=${task.startTime} sound=${task.alarmSound} dueDates=${dueDates.length}',
    );
    int notifId = ((task.id.hashCode & 0x7FFFFFFF) % 2000000) + 2000000;

    final prefs = await SharedPreferences.getInstance();

    for (final dueDate in dueDates) {
      DateTime alarmTime;
      if (task.startTime != null) {
        final parts = task.startTime!.split(':');
        alarmTime = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } else {
        continue; // Alarm needs a time
      }

      if (alarmTime.isBefore(now)) {
        // Grace window: if alarm time just passed (within 5 min), schedule for 5s from now
        final diff = now.difference(alarmTime).inSeconds;
        if (diff <= 300) {
          debugPrint(
            '[ALARM] alarm at $alarmTime just passed (${diff}s ago), scheduling for now+5s',
          );
          alarmTime = now.add(const Duration(seconds: 5));
        } else {
          debugPrint('[ALARM] skipping past alarm: $alarmTime');
          continue;
        }
      }

      final currentId = notifId++;

      await prefs.setString('alarm_${currentId}_title', task.title);
      if (task.description != null) {
        await prefs.setString('alarm_${currentId}_body', task.description!);
      }
      if (task.alarmSound != null) {
        await prefs.setString('alarm_${currentId}_sound', task.alarmSound!);
      }
      await prefs.setString('alarm_${currentId}_taskId', task.id);
      await prefs.setInt(
        'alarm_${currentId}_snoozeMinutes',
        task.snoozeMinutes,
      );

      debugPrint('[ALARM] Scheduling alarm at $alarmTime (id=$currentId)');

      if (Platform.isAndroid) {
        try {
          await AndroidAlarmManager.oneShotAt(
            alarmTime,
            currentId,
            alarmManagerCallback,
            alarmClock: true,
            rescheduleOnReboot: true,
          );
          debugPrint(
            '[ALARM] Alarm scheduled via AndroidAlarmManager (alarmClock',
          );
        } catch (e) {
          debugPrint(
            '[ALARM] alarmClock failed: $e, failed back to exact+allowWhileIdle',
          );
          await AndroidAlarmManager.oneShotAt(
            alarmTime,
            currentId,
            alarmManagerCallback,
            exact: true,
            wakeup: true,
            allowWhileIdle: true,
            rescheduleOnReboot: true,
          );
          debugPrint(
            '[ALARM] Alarm scheduled via AndroidAlarmManager (exact fallback)',
          );
        }
      } else {
        final scheduledDate = tz.TZDateTime.from(alarmTime, tz.local);
        await _plugin.zonedSchedule(
          id: currentId,
          title: '⏰ ${task.title}',
          body: task.description,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'alarm_${task.id}',
        );
        debugPrint('[ALARM] Alarm scheduled via zonedSchedule (iOS)');
      }
    }

    // Verify alarms are actually pending
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[ALARM] Total pending notifications: ${pending.length}');
    for (final p in pending) {
      debugPrint('[ALARM] pending id=${p.id} title=${p.title}');
    }
  }

  Future<void> cancelForTask(String taskId) async {
    // Cancel a range of notification IDs derived from the task
    final baseId = (taskId.hashCode & 0x7FFFFFFF) % 2000000;
    for (int i = 0; i < 50; i++) {
      await _plugin.cancel(id: baseId + i);
    }
    final alarmBase = baseId + 2000000;
    for (int i = 0; i < 20; i++) {
      if (Platform.isAndroid) {
        await AndroidAlarmManager.cancel(alarmBase + i);
      }
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
