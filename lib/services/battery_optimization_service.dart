import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


class BatteryOptimizationService {
  static const _channel = MethodChannel('com.mk.life_pilot/battery');

  /// check if battery is already disable for this app
  static Future<bool> isIgnoringBatteryOptimization() async {
    if(!Platform.isAndroid) return true;
    try{
      return await _channel.invokeMethod('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return true; // Assume ok if check fail
    }
  }

  /// Show the system dialog asking user to disable battery optimization (one-tap)
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod('requestIgnoreBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show the system dialog asking user to disable battery optimization (one-tap)
  static Future<bool> openBatterySettings() async {
    if(!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod('openBatterySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getManufacture() async {
    if(!Platform.isAndroid) return '';
    try {
      return await _channel.invokeMethod('getManufacturer') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Known aggressive OEMs thet need extra batery settings
  static const _aggresiveOems = {
    'xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo', 'realme', 'vivo', 'iqoo', 'oneplus', 'meizu', 'asus', 'samsung', 'tecno', 'infinix', 'transsion',
  };

  /// Check if device is from an OEM know for aggressive battery optimization
  static Future<bool> isAggressiveOne() async {
    final manufacture = await getManufacture();
    return _aggresiveOems.contains(manufacture);
  }

  /// Get OEM-specific instructions for the user
  static String getOemInstructions(String manufacturer) {
    switch (manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return 'Settings -> Apps -> Manage apps -> DayPilot -> Battery Saver -> No restrictions \n Also enable Autostart in Security app -> Manage apps -> DayPilot.';
      case 'huawei':
      case 'honor':
        return 'Settings -> Battery -> App launch -> DayPilot -> Toggle Off "Manage Automatically" and enable all three switches (Auto launch, Secondary launch, Run in background';
      case 'oppo':
      case 'realme':
        return 'Settings -> Battery -> More battery settings -> Optimize battery use -> DayPilot -> Don\'tt optimize. \n\n Also: Settings -> App Management -> DayPilot -> Allow auto-startup and Allow background activity.';
      case 'vivo':
      case 'iqoo':
        return 'Settings -> Battery -> Background power consumer management -> DayPilot -> Allow. \n\n Also. Settings -> More settings -> Applications -> Autostart -> Enable DayPliot';
      case 'one plus':
        return 'Settings -> Battery -> Battery optimization -> DayPilot -> Don\'t optimize. \n\n Also Settings -> Apps -> DayPilot -> Battery -> Allow background activity';
      case 'samsung':
        return 'Settings -> Battery and device care -> Battery -> Background usage limits -> Naver sleeping apps -> Add DayPilot';
        default:
          return 'Settings -> Battery -> optimization -> DayPilot -> Don\'t optimize';
    }
  }

  /// Show battery optimization dialog if needed. Returns true if already optimized
  /// When called from Settings (force=true), always shows even if previously dismissed.
  static Future<bool> checkAndPrompt(BuildContext context, {bool force = false}) async {
    if(!Platform.isAndroid) return true;

    final isIgnoring = await isIgnoringBatteryOptimization();
    if (isIgnoring) return true;

    // Don't nag on every app launch - only prompt once unless forced from Settings.
    if(!force) {
      final prefs = await SharedPreferences.getInstance();
      final prompted = prefs.getBool('battery_opt_prompted') ?? false;
      if (prompted) return false;
      await prefs.setBool('battery_opt_prompted', true);
    }

    if (!context.mounted) return false;

    final manufacturer = await getManufacture();
    final isAggressive = _aggresiveOems.contains(manufacturer);
    
    await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.battery_alert, size: 48, color: Colors.orange),
          title: const Text('Disable battery optimization'),
          content: Text(
              'For alarm to ring reliably (even when the app is closed),'
                  'DayPilot needs to be excluded from battery optimization. \n\n'
                  '${isAggressive ? 'Your ${manufacturer[0].toUpperCase()}${manufacturer.substring(1)} device has aggressive battery management'
                  '${getOemInstructions(manufacturer)}' : 'Tap "Allow" on the next screen.'}',

          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await requestIgnoreBatteryOptimizations();
                }, child: const Text('Disable optimization'),
            ),
            if (isAggressive)
              TextButton(onPressed: () async {
                Navigator.pop(ctx);
                await openBatterySettings();
              }, child: const Text('Open battery settings'),
              ),
          ],
        )
    );

    return false;
  }
}