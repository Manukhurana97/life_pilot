import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioTrimResult {
  final double startSec;
  final double endSec;

  const AudioTrimResult({required this.startSec, required this.endSec});
}

class AudioTrimScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AudioTrimScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AudioTrimScreen> createState() => _AudioTrimScreenState();
}

class _AudioTrimScreenState extends State<AudioTrimScreen> {
  final AudioPlayer _player = AudioPlayer();
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;

  double _startSec = 0;
  double _endSec = 30;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async{
    // Listen to position change
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
        // Stop at end of selected range during preview
        if(_isPlaying && pos.inMicroseconds >= (_endSec * 1000).round()) {
          _player.pause();
          setState(() => _isPlaying = false);
        }
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if(mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    // Get duration
    await _player.setSource(DeviceFileSource(widget.filePath));
    final dur = await _player.getDuration();
    if(dur != null && mounted) {
      setState(() {
        _totalDuration = dur;
        _endSec = dur.inSeconds.toDouble().clamp(1, 30);
        if(_endSec > dur.inMilliseconds / 1000.0) {
          _endSec = dur.inMilliseconds / 1000.0;
        }
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  double get _maxDuration => 
    _totalDuration.inMilliseconds / 1000.0;

  double get _selectedDuration => _endSec - _startSec;

  String _formatDuration(double seconds) {
    final mins = seconds ~/ 60;
    final sec = (seconds % 60).toStringAsFixed(1);
    return mins > 0 ? '$mins:${sec.padLeft(4, '0')}' : '${sec}s';
  }

  Future<void> _playSelection() async {
    if(_isPlaying) {
      await _player.pause();
      return;
    }

    await _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
    await _player.resume();
  }

  void _confirm() {
    _player.stop();
    Navigator.of(context).pop(
      AudioTrimResult(startSec: _startSec, endSec: _endSec),
    );
  }

  void _cancel() {
    _player.stop();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trim Audio'),
        leading: IconButton(
          onPressed: _cancel, 
          icon: const Icon(Icons.close)
        ),
        actions: [
          TextButton(
            onPressed: _selectedDuration >= 1 ? _confirm : null, 
            child: const Text('Done'),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File name
              Text(
                widget.fileName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),  
              const SizedBox(height: 8),
              Text(
                'Total: ${_formatDuration(_maxDuration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),
              

              // Selected duration indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12
                ),decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.content_cut,
                    size: 20, 
                    color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: ${_formatDuration(_selectedDuration)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      )
                    )
                  ],
                ),  
              ),
              const SizedBox(height: 8),
              if (_selectedDuration > 30) 
                Text(
                  'Max 30 seconds allowed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 24),

              // Timeline bar
              Column(
                children: [
                  // Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_startSec),
                        style: theme.textTheme.bodySmall),
                      Text(_formatDuration(_endSec), 
                        style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Range Slider
                  SliderTheme(
                    data: SliderThemeData(
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10
                      ),
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                      thumbColor: theme.colorScheme.primary,
                      overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ), 
                    child: RangeSlider(
                      values: RangeValues(_startSec, _endSec),
                      min: 0,
                      max: _maxDuration,
                      divisions: (_maxDuration * 10).round().clamp(1, 10000), 
                      onChanged: (values) {
                        double newStart = values.start;
                        double newEnd = values.end;

                        //Enforce max 30 sec window
                        if (newEnd - newStart > 30) {
                          // Determine which thumb moved
                          if((newStart - _startSec).abs() > (newEnd - _endSec).abs()) {
                            newStart = newEnd - 30;
                          } else {
                            newEnd = newStart + 30;
                          }
                        }

                        // Enforce min 1 sec
                        if(newEnd - newStart < 1) return;

                        setState(() {
                          _startSec = newStart.clamp(0, _maxDuration);
                          _endSec = newEnd.clamp(0, _maxDuration);
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Play button
              Center(
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _playSelection,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPlaying 
                ? '${_formatDuration(_currentPosition.inMilliseconds / 1000.0)} / ${_formatDuration(_selectedDuration)}'
                : 'Preview selection',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Confirm button
              FilledButton.icon(
                onPressed: _selectedDuration >= 1 && _selectedDuration <= 30 ? _confirm : null,
                icon: const Icon(Icons.check), 
                label: Text('Use this chip (${_formatDuration(_selectedDuration)})'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cancel, 
                child: const Text('Cancel'),
              )
            ],
          )
        )
    );
  }
}