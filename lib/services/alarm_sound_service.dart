import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSound {
  final String id;
  final String name;
  final bool isBuildIn;
  final String? filePath; // null for build-in absolute path for custom

  const AlarmSound({
    required this.id,
    required this.name,
    this.isBuildIn = false,
    this.filePath,
  });

  Map<String, String> toJoin() => {
    'id': id,
    'name': name,
    'isBuildIn': isBuildIn.toString(),
    'filePath': filePath ?? '',
  };

  factory AlarmSound.fromJson(Map<String, String> json) => AlarmSound(
    id: json['id']!, 
    name: json['name']!,
    isBuildIn: json['isBuildIn'] == 'true',
    filePath: json['filePath']?.isEmpty == true ? null : json['filePath']
    );
}

class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  static const _customSoundKey = 'custom_alarm_sounds';
  static const _customSoundsDir = 'alarm_sounds';

  /// Build-in alarm sounds (blunder as assets)
  static const List<AlarmSound> buildInSounds = [
    AlarmSound(id: 'default', name: 'Default Alarm', isBuildIn: true),
  ];

  /// Get all available sounds (build-in + custom)
  Future<List<AlarmSound>> getAllSounds() async {
    final customs = await getCustomSounds();
    return [...buildInSounds, ...customs];
  }

  /// Get custom sounds from storage
  Future<List<AlarmSound>> getCustomSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_customSoundKey) ?? [];
    final sounds = <AlarmSound>[];

    for (final entry in entries) {
      final parts = entry.split('|||');
      if (parts.length == 3) {
        final file = File(parts[2]);
        if (await file.exists()) {
          sounds.add(
            AlarmSound(
              id: parts[0],
              name: parts[1],
              isBuildIn: false,
              filePath: parts[2],
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return null;

      return (path: pickedFile.path!, name: pickedFile.name);
    } catch (e) {
      debugPrint('Error picking, audio file: $e');
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
        isBuildIn: false,
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
    final entries = prefs.getStringList(_customSoundKey) ?? [];
    entries.add('${sound.id} |||${sound.name}|||${sound.filePath}');
    await prefs.setStringList(_customSoundKey, entries);
  }

  // Delete a custom Sound
  Future<void> deleteCustomSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_customSoundKey) ?? [];
    final updated = <String>[];

    for(final entry in entries) {
        final parts = entry.split('|||');
        if (parts.isNotEmpty && parts[0] == soundId) {
            // Delete the file
            if (parts.length == 3) {
                final file = File(parts[2]);
                if(await file.exists()) {
                    await file.delete();
                }
            } 
        }else {
            updated.add(entry);
        }
    }
    await prefs.setStringList(_customSoundKey, updated);
  }

  /// Find a sound by ID
  Future<AlarmSound?> getSoundById(String? id) async {
    if (id == null || id.isEmpty ) return buildInSounds.first;

    // Check build-in
    for (final s in buildInSounds) {
        if(s.id == id) return s;
    }

    // Check custom
    final custom = await getCustomSounds();
    for (final s in custom) {
        if(s.id == id) return s;
    }

    return buildInSounds.first;
  }

  /// Preview a sound (play / stop toggle)
  Future<void> previewSound(AlarmSound sound) async {
    if(_isPlaying) {
        await stopPreview();
        return;
    }

    try {
        if(sound.isBuildIn) {
            await _player.play(AssetSource('sounds/${sound.id}.mp3'));
        } else if(sound.filePath != null) {
            await _player.play(DeviceFileSource(sound.filePath!));
        }
        _isPlaying = true;

        // Autop-slop after 5 sec
        Future.delayed(const Duration(seconds: 5), () {
            if(_isPlaying) stopPreview();
        });
    } catch(e) {
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

    /// Playing alarm sound (for alarm screen - loops untill stopped
    Future<void> playAlarm(String? soundId) async {
        final sound = await getSoundById(soundId);
        if(sound == null) return;

        try {
            await _player.setReleaseMode(ReleaseMode.loop);
            if(sound.isBuildIn) {
                await _player.play(AssetSource('sounds/${sound.id}.mp3'));
            } else if(sound.filePath != null) {
                await _player.play(DeviceFileSource(sound.filePath!));
            }
            _isPlaying = true;
        } catch (e) {
            debugPrint("Error playing alarm: $e");
        }
    }

    /// Stop alarm sound
    Future<void> stopAlarm() async {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.release);
        _isPlaying = false;
    }

    void dispose() {
        _player.dispose();
    }
}
