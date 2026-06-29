import 'dart:async';
import 'dart:math';
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

  int _clipsDurationSec = 20;
  double _scrollOffSetSec = 0;
  double _selectionOffsetSec = 30;

  static const double _visibleWindowSec = 90;
  List<double> _waveformBars = [];
  static const double _barWidth = 3.0;
  static const double _barGap = 2.0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _autoPlayDebounce;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);

        if (_isPlaying &&
            pos.inMilliseconds >= (_startSec + _clipsDurationSec) * 1000) {
          _player.pause();
          setState(() => _isPlaying = false);
        }
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    await _player.setSource(DeviceFileSource(widget.filePath));
    final dur = await _player.getDuration();
    if (dur != null && mounted) {
      setState(() {
        _totalDuration = dur;
        _clipsDurationSec = min(20, max(1, _maxDuration.floor())).clamp(1, 30);
        _selectionOffsetSec = (_visibleWindowSec - _clipsDurationSec) / 2;
        _selectionOffsetSec = _selectionOffsetSec.clamp(
          0,
          _effectiveVisibleSec - _clipsDurationSec,
        );
        _generateWaveform();
        _isLoading = false;
      });
      _autoPlay();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _autoPlayDebounce?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  double get _maxDuration => _totalDuration.inMilliseconds / 1000.0;

  double get _effectiveVisibleSec => min(_visibleWindowSec, _maxDuration);

  double get _maxScrollOffset => max(0, _maxDuration - _effectiveVisibleSec);

  double get _startSec => _scrollOffSetSec + _selectionOffsetSec;

  double get _endSec => (_startSec + _clipsDurationSec).clamp(0, _maxDuration);

  void _generateWaveform() {
    final barsPerSec = 0.8;
    final totalBars = max(1, (_maxDuration * barsPerSec).ceil());
    final rng = Random(widget.filePath.hashCode);
    _waveformBars = List.generate(
      totalBars,
      (_) => 0.15 + rng.nextDouble() * 0.85,
    );
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _autoPlay() async {
    _autoPlayDebounce?.cancel();
    _autoPlayDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      await _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
      await _player.resume();
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.seek(Duration(milliseconds: (_startSec * 1000).round()));
      await _player.resume();
    }
  }

  void _onClipDurationChanged(int newDuration) {
    setState(() {
      _clipsDurationSec = newDuration;
      if (_selectionOffsetSec + _clipsDurationSec > _effectiveVisibleSec) {
        _selectionOffsetSec = max(0, _effectiveVisibleSec - _clipsDurationSec);
      }
      if (_startSec + _clipsDurationSec > _maxDuration) {
        _selectionOffsetSec = max(
          0,
          _maxDuration - _clipsDurationSec - _scrollOffSetSec,
        );
        if (_selectionOffsetSec < 0) {
          _scrollOffSetSec = max(0, _maxDuration - _clipsDurationSec);
          _selectionOffsetSec = 0;
        }
      }
    });
    _autoPlay();
  }

  void _confirm() {
    _player.stop();
    Navigator.of(
      context,
    ).pop(AudioTrimResult(startSec: _startSec, endSec: _endSec));
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
        leading: IconButton(onPressed: _cancel, icon: const Icon(Icons.close)),
        actions: [
          TextButton(
            onPressed: _clipsDurationSec >= 3 ? _confirm : null,
            child: const Text('Done'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${_formatTime(_maxDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    _buildControlRow(theme),

                    const SizedBox(height: 16),

                    _buildWaveformArea(theme),

                    const SizedBox(height: 12),

                    // Time labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_startSec),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '${_formatTime(_startSec)} - ${_formatTime(_endSec)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          _formatTime(_endSec),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Playing status
                    if (_isPlaying)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${_formatTime(_currentPosition.inMilliseconds / 1000.0)} / ${_formatTime(_clipsDurationSec.toDouble())}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Confirm button
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check),
                      label: Text('Use this clip (${_clipsDurationSec}s)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildControlRow(ThemeData theme) {
    final totalFraction = _maxDuration > 0 ? _startSec / _maxDuration : 0.0;
    final endFraction = _maxDuration > 0 ? _endSec / _maxDuration : 0.0;

    return Row(
      children: [
        // Duration dropdown (circle)
        GestureDetector(
          onTap: () => _showDurationPicker(theme),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$_clipsDurationSec',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Position indicator dot + bar
        Expanded(
          child: SizedBox(
            height: 12,
            child: CustomPaint(
              painter: _PositionIndicatorPainter(
                startFraction: totalFraction,
                endFraction: endFraction,
                activeColor: Colors.red,
                dotColor: theme.colorScheme.tertiary,
                trackColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Play bottom
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSurface,
            ),
            alignment: Alignment.center,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: theme.colorScheme.surface,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  void _showDurationPicker(ThemeData theme) {
    final maxAllowed = min(30, _maxDuration.floor()).clamp(1, 30);
    const minAllowed = 3;
    final effectiveMin = min(minAllowed, maxAllowed);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Clip Duration', style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: maxAllowed - effectiveMin + 1,
                itemBuilder: (ctx, i) {
                  final sec = i + effectiveMin;
                  return ListTile(
                    title: Text('$sec seconds'),
                    trailing: sec == _clipsDurationSec
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onClipDurationChanged(sec);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformArea(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final pixelsPerSec = availableWidth / _effectiveVisibleSec;
        final selectionWidth = _clipsDurationSec * pixelsPerSec;
        final selectionLeft = _selectionOffsetSec * pixelsPerSec;

        return SizedBox(
          height: 40,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final secDelta = -details.delta.dx / pixelsPerSec;
              setState(() {
                _scrollOffSetSec = (_scrollOffSetSec + secDelta).clamp(
                  0,
                  _maxScrollOffset,
                );
                if (_selectionOffsetSec + _clipsDurationSec >
                    _effectiveVisibleSec) {
                  _selectionOffsetSec = max(
                    0,
                    _effectiveVisibleSec - _clipsDurationSec,
                  );
                }
                if (_startSec + _clipsDurationSec > _maxDuration) {
                  _selectionOffsetSec = max(
                    0,
                    _maxDuration - _clipsDurationSec - _scrollOffSetSec,
                  );
                }
              });
            },
            onHorizontalDragEnd: (_) => _autoPlay(),
            child: Stack(
              children: [
                ClipRect(
                  child: CustomPaint(
                    size: Size(availableWidth, 40),
                    painter: _WaveformPainter(
                      bars: _waveformBars,
                      scrollOffsetSec: _scrollOffSetSec,
                      visibleWindowSec: _effectiveVisibleSec,
                      totalDurationSec: _maxDuration,
                      barColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                      selectedBarColor: Colors.red,
                      selectedStartSec: _startSec,
                      selectedEndSec: _endSec,
                      barWidth: _barWidth,
                      barGap: _barGap,
                    ),
                  ),
                ),

                Positioned(
                  left: selectionLeft,
                  top: 0,
                  bottom: 0,
                  width: selectionWidth,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final secDelta = details.delta.dx / pixelsPerSec;
                      setState(() {
                        _selectionOffsetSec = (_selectionOffsetSec + secDelta)
                            .clamp(0, _effectiveVisibleSec - _clipsDurationSec);

                        if (_startSec + _clipsDurationSec > _maxDuration) {
                          _selectionOffsetSec = max(
                            0,
                            _maxDuration - _clipsDurationSec - _scrollOffSetSec,
                          );
                        }
                      });
                    },
                    onHorizontalDragEnd: (_) => _autoPlay(),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.onSurface,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                if (_isPlaying)
                  Builder(
                    builder: (_) {
                      final posSec = _currentPosition.inMilliseconds / 1000.0;
                      final posInView = posSec - _scrollOffSetSec;
                      if (posInView < 0 || posInView > _effectiveVisibleSec) {
                        return const SizedBox.shrink();
                      }
                      final posX = posInView * pixelsPerSec;
                      return Positioned(
                        left: posX,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double scrollOffsetSec;
  final double visibleWindowSec;
  final double totalDurationSec;
  final Color barColor;
  final Color selectedBarColor;
  final double selectedStartSec;
  final double selectedEndSec;
  final double barWidth;
  final double barGap;

  _WaveformPainter({
    required this.bars,
    required this.scrollOffsetSec,
    required this.visibleWindowSec,
    required this.totalDurationSec,
    required this.barColor,
    required this.selectedBarColor,
    required this.selectedStartSec,
    required this.selectedEndSec,
    this.barWidth = 3.0,
    this.barGap = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || totalDurationSec <= 0) return;

    final barStep = barWidth + barGap;
    final barsOnScreen = (size.width / barStep).floor();
    final centerY = size.height / 2;

    final visibleStartFrac = scrollOffsetSec / totalDurationSec;
    final visibleEndFrac =
        (scrollOffsetSec + visibleWindowSec) / totalDurationSec;

    for (int i = 0; i < barsOnScreen; i++) {
      final frac = i / barsOnScreen;
      final songFrac =
          visibleStartFrac + frac * (visibleEndFrac - visibleStartFrac);
      final barIndex = (songFrac * bars.length).floor().clamp(
        0,
        bars.length - 1,
      );

      final x = i * barStep + barWidth / 2;
      final barHeight = bars[barIndex] * (size.height * 0.8);

      final barTimeSec = songFrac * totalDurationSec;
      final isSelected =
          barTimeSec >= selectedStartSec && barTimeSec <= selectedEndSec;

      final paint = Paint()
        ..color = isSelected ? selectedBarColor : barColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}

class _PositionIndicatorPainter extends CustomPainter {
  final double startFraction;
  final double endFraction;
  final Color activeColor;
  final Color dotColor;
  final Color trackColor;

  _PositionIndicatorPainter({
    required this.startFraction,
    required this.endFraction,
    required this.activeColor,
    required this.dotColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = trackColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final startX = startFraction * size.width;
    final endX = endFraction * size.width;
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      Paint()
        ..color = activeColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(startX, centerY), 4, dotPaint);
    canvas.drawCircle(Offset(endX, centerY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PositionIndicatorPainter old) => true;
}
