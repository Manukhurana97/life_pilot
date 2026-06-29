import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSound {
  final String id;
  final String name;
  final bool isBuiltIn;
  final String? filePath; // null for build-in absolute path for custom
  final double startSec;
  final double endSec;

  const AlarmSound({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.filePath,
    this.startSec = 0,
    this.endSec = 0,
  });

  Map<String, String> toJoin() => {
    'id': id,
    'name': name,
    'isBuiltIn': isBuiltIn.toString(),
    'filePath': filePath ?? '',
    'startSec': startSec.toString(),
    'endSec': startSec.toString(),
  };

  factory AlarmSound.fromJson(Map<String, String> json) => AlarmSound(
    id: json['id']!,
    name: json['name']!,
    isBuiltIn: json['isBuiltIn'] == 'true',
    filePath: json['filePath']?.isEmpty == true ? null : json['filePath'],
    startSec: double.tryParse(json['startSec'] ?? '') ?? 0,
    endSec: double.tryParse(json['endSec'] ?? '') ?? 0,
  );
}

class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  static const _customSoundsKey = 'custom_alarm_sounds';
  static const _customSoundsDir = 'alarm_sounds';

  /// All build-in alarm sounds
  static const List<AlarmSound> _allBuiltInSounds = [
    AlarmSound(id: 'android', name: 'Android Alarm', isBuiltIn: true),
    AlarmSound(id: 'ios', name: 'iOS Alarm', isBuiltIn: true),
  ];

  /// Platform-filtered build-in sounds (android.mp3 for Android, ios.mp3 for iOS)
  static List<AlarmSound> get builtInSounds => _allBuiltInSounds
      .where((s) => s.id == defaultSoundId)
      .toList();

  /// Build-In  alarm sound (bundled as assets)
  static String get defaultSoundId => Platform.isIOS ? 'ios' : 'android';

  /// Get all available sounds (build-in + custom)
  Future<List<AlarmSound>> getAllSounds() async {
    final customs = await getCustomSounds();
    return [...builtInSounds, ...customs];
  }

  /// Get custom sounds from storage
  Future<List<AlarmSound>> getCustomSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_customSoundsKey) ?? [];
    final sounds = <AlarmSound>[];

    for (final entry in entries) {
      final parts = entry.split('|||');
      if (parts.length >= 3) {
        final file = File(parts[2]);
        if (await file.exists()) {
          sounds.add(
            AlarmSound(
              id: parts[0],
              name: parts[1],
              isBuiltIn: false,
              filePath: parts[2],
              startSec: parts.length > 3 ? (double.tryParse(parts[3]) ?? 0) : 0,
              endSec: parts.length > 4 ? (double.tryParse(parts[4]) ?? 0) : 0,
            ),
          );
        }
      }
    }

    return sounds;
  }

  /// Pick an audio file from device (returns temp path + name for trim screen)
  Future<({String path, String name})?> pickAudioFile() async {
    try {
      const audioTypeGroup = XTypeGroup(
        label: 'Audio',
        mimeTypes: ['audio/*'],
        uniformTypeIdentifiers: ['public.audio'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [audioTypeGroup],
      );

      if (file == null) return null;

      return (
      path: file.path,
      name: file.name,
      );
    } catch (e) {
      debugPrint('Error picking audio file: $e');
      return null;
    }
  }

  /// Trim audio file and save to app storage
  Future<AlarmSound?> trimAndSave({
    required String sourcePath,
    required String fileName,
    required double startSec,
    required double endSec,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soundsDir = Directory(p.join(appDir.path, _customSoundsDir));
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      final ext = p.extension(sourcePath);
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final destPath = p.join(soundsDir.path, '$id$ext');

      // Use FFmpeg to trim audio
      await File(sourcePath).copy(destPath);

      final baseName = fileName.replaceAll(ext, '');
      final sound = AlarmSound(
        id: id,
        name: baseName,
        isBuiltIn: false,
        filePath: destPath,
      );

      await _saveCustomSound(sound);
      return sound;
    } catch (e) {
      debugPrint('Error triming alarm sound: $e');
      return null;
    }
  }

  Future<void> _saveCustomSound(AlarmSound sound) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_customSoundsKey) ?? [];
    entries.add('${sound.id}|||${sound.name}|||${sound.filePath}|||${sound.startSec}|||${sound.endSec}');
    await prefs.setStringList(_customSoundsKey, entries);
  }

  // Delete a custom Sound
  Future<void> deleteCustomSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_customSoundsKey) ?? [];
    final updated = <String>[];

    for (final entry in entries) {
      final parts = entry.split('|||');
      if (parts.isNotEmpty && parts[0] == soundId) {
        // Delete the file
        if (parts.length == 3) {
          final file = File(parts[2]);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } else {
        updated.add(entry);
      }
    }
    await prefs.setStringList(_customSoundsKey, updated);
  }

  /// Find a sound by ID
  Future<AlarmSound?> getSoundById(String? id) async {
    final fallback = builtInSounds.firstWhere((s) => s.id == defaultSoundId);
    if (id == null || id.isEmpty) return fallback;

    // Check built-in
    for (final s in builtInSounds) {
      if (s.id == id) return s;
    }

    // Check custom
    final custom = await getCustomSounds();
    for (final s in custom) {
      if (s.id == id) return s;
    }

    return fallback;
  }

  /// Preview a sound (play / stop toggle)
  Future<void> previewSound(AlarmSound sound) async {
    if (_isPlaying) {
      await stopPreview();
      return;
    }

    try {
      final hasTrim = !sound.isBuiltIn && sound.endSec > sound.startSec;
      debugPrint('[PREVIEW] sound=${sound.name} startSec=${sound.startSec} endSec=${sound.endSec} hasTrim=$hasTrim');

      if (sound.isBuiltIn) {
        await _player.play(AssetSource('sounds/${sound.id}.mp3'));
      } else if (sound.filePath != null) {
        await _player.setSource(DeviceFileSource(sound.filePath!));
        if (hasTrim) {
          debugPrint('[PREVIEW] Seeking to ${sound.startSec}s');
          await _player.seek(Duration(milliseconds: (sound.startSec * 1000).round()));
        }
        await _player.resume();
      }
      _isPlaying = true;

      // Auto-stop after 5 sec
      final stopAfter = hasTrim
      ? Duration(milliseconds: ((sound.endSec - sound.startSec) * 1000).round())
      : const Duration(seconds: 5);

      Future.delayed(stopAfter, () {
        if (_isPlaying) stopPreview();
      });
    } catch (e) {
      debugPrint('Error previewing sound: $e');
      _isPlaying = false;
    }
  }

  /// Stop preview playback
  Future<void> stopPreview() async {
    await _player.stop();
    _isPlaying = false;
  }

  bool get isPlaying => _isPlaying;
  StreamSubscription<Duration>? _positionSub;

  /// Playing alarm sound (for alarm screen - loops untill stopped)
  Future<void> playAlarm(String? soundId) async {
    final sound = await getSoundById(soundId);
    if (sound == null) return;

    try {
      // For custom sounds with trim range, we manually loop within startSec-endSec
      final hasTrim = !sound.isBuiltIn && sound.endSec > sound.startSec;

      if (hasTrim) {
        await _player.setReleaseMode(ReleaseMode.release);
      } else {
        await _player.setReleaseMode(ReleaseMode.loop);
      }

      if (sound.isBuiltIn) {
        await _player.play(AssetSource('sounds/${sound.id}.mp3'));
      } else if (sound.filePath != null) {
        await _player.setSource(DeviceFileSource(sound.filePath!));
        if (hasTrim) {
          await _player.seek(Duration(milliseconds: (sound.startSec * 1000).round()));
        }
        await _player.resume();
      }
      _isPlaying = true;

      // Monitor position to loop within trim range
      if (hasTrim) {
        _positionSub?.cancel();
        _positionSub = _player.onPositionChanged.listen((pos) {
          if (pos.inMilliseconds >= (sound.endSec * 1000).round()) {
            _player.seek(Duration(milliseconds: (sound.startSec * 1000).round()));
          }
        });
      }
    } catch (e) {
      debugPrint("Error playing alarm: $e");
    }
  }

  /// Stop alarm sound
  Future<void> stopAlarm() async {
    _positionSub?.cancel();
    _positionSub = null;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.release);
    _isPlaying = false;
  }

  void dispose() {
    _player.dispose();
  }
}
