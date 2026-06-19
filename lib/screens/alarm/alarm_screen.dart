import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/services/alarm_sound_service.dart';

class AlarmScreen extends StatefulWidget {
  final String taskTitle;
  final String? taskDescription;
  final int snoozeMinutes;
  final String? alarmSoundId;

  const AlarmScreen({
    super.key,
    required this.taskTitle,
    this.taskDescription,
    this.snoozeMinutes = 5,
    this.alarmSoundId,    
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> 
  with SingleTickerProviderStateMixin {
    late AnimationController _pulseController;
    late Timer _timeTimer;
    String _currentTime = '';
    final AlarmSoundService _soundService = AlarmSoundService();

    @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    // Vibrate and play alarm sound
    HapticFeedback.heavyImpact();
    _soundService.playAlarm(widget.alarmSoundId);
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _soundService.stopAlarm();
    _pulseController.dispose();
    _timeTimer.cancel();
    super.dispose();
  }

  void _dismiss() {
    _soundService.stopAlarm();
    Navigator.of(context).pop('dismiss');
  }

  void _snooze() {
   _soundService.stopAlarm();
    Navigator.of(context).pop('snooze');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Pulsing alarm icon
              AnimatedBuilder(
                animation: _pulseController, 
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.15);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100, 
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.errorContainer,
                      ),
                      child: Icon(
                        Icons.alarm,
                        size: 40,
                        color: theme.colorScheme.error,
                      )
                    ),
                  );
                }, 
              ),
              const SizedBox(height: 40),

              // Time
              Text(
                _currentTime,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontSize: 72
                ),
              ),
              const SizedBox(height: 16),

              // Tast title
              Text(
                widget.taskTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600
                ),
                textAlign: TextAlign.center,
              ),

              if(widget.taskDescription != null && widget.taskDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.taskDescription!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _dismiss, 
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Dismiss', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Snooze button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _snooze,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(28),
                    ),
                  ),
                  child: Text(
                    'Snooze (${widget.snoozeMinutes} min)',
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}