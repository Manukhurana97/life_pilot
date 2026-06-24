import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/models/subtask.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/core/constraints/app_constraints.dart';
import 'package:life_pilot/services/alarm_sound_service.dart';
import 'package:life_pilot/screens/alarm/audio_trim_screen.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? existingTask;

  const TaskFormScreen({super.key, this.existingTask});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _categoryId;
  TaskPriority _priority = TaskPriority.medium;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  RecurrenceType _recurrenceType = RecurrenceType.oneTime;
  List<int> _selectedDay = [];
  int _weekday = 1; // For weekly / biweekly;
  int _dayOfMonth = 1;
  int _intervalMonths = 1;
  int _intervalDays = 1;
  int _ordinal = 1;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<int> _reminderOffsets = [];
  bool _isAlarm = false;
  int _snoozeMinutes = 5;
  String? _alarmSoundId;
  List<AlarmSound> _availableSounds = [];
  final AlarmSoundService _soundService = AlarmSoundService();
  final List<TextEditingController> _subtaskControllers = [];

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromTask(widget.existingTask!);
      _loadSubtasks();
    }
    _loadAvailableSounds();
  }

  Future<void> _loadAvailableSounds() async {
    _availableSounds = await _soundService.getAllSounds();
    if (mounted) setState(() {});
  }

  void _populateFromTask(Task task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _categoryId = task.categoryId;
    _priority = task.priority;
    _recurrenceType = task.recurrenceType;
    _startDate = DateTime.parse(task.startDate);
    _endDate = task.endDate != null ? DateTime.parse(task.endDate!) : null;
    _reminderOffsets = List.from(task.reminderOffsets);
    _isAlarm = task.isAlarm;
    _alarmSoundId = task.alarmSound;
    _snoozeMinutes = task.snoozeMinutes;

    if(task.startTime != null) {
      final parts = task.startTime!.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    if(task.endTime != null) {
      final parts = task.endTime!.split(':');
      _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    // Recurrence data
    final data = task.recurrenceDate;
    _selectedDay = List<int>.from(data['days'] ?? []);
    _weekday = data['weekday'] ?? 1;
    _dayOfMonth = data['dayOfMonth'] ?? 1;
    _intervalMonths = data['interval'] ?? 1;
    _intervalDays = data['intervalDays'] ?? 1;
    _ordinal = data['ordinal'] ?? 1;
  }

  Future<void> _loadSubtasks() async {
    final subtasks = await ref.read(taskProvider).getSubtasks(widget.existingTask!.id);
    if (mounted) {
      setState(() {
        for (final st in subtasks) {
          _subtaskControllers.add(TextEditingController(text: st.title));
        }
      });
    }
  }

  @override
  void dispose() {
    _soundService.stopPreview();
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildRecurrenceData() {
    switch(_recurrenceType) {
      case RecurrenceType.oneTime:
      case RecurrenceType.daily:
        return {};
      case RecurrenceType.specificDays:
        return {'days': _selectedDay};
      case RecurrenceType.weekly:
        return {'weekdays': _weekday, 'interval': 1};
      case RecurrenceType.biweekly:
        return {'weekdays': _weekday};
      case RecurrenceType.monthlyDate:
        return {'dayOfMonth': _dayOfMonth, 'interval': _intervalMonths};
      case RecurrenceType.monthlyOrdinal:
        return {
          'ordinal': _ordinal,
          'weekday': _weekday,
          'interval': _intervalMonths
        };
      case RecurrenceType.quarterly:
        return {'dayOfMonth': _dayOfMonth};
      case RecurrenceType.yearly:
        return {'month': _startDate.month, 'dayOfMonth': _startDate.day};
      case RecurrenceType.customInterval:
        return {'intervalDays': _intervalDays};
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();
    final task = Task(
      id: widget.existingTask?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      categoryId: _categoryId,
      priority: _priority,
      startTime: _startTime != null ? _formatTime(_startTime!) : null,
      endTime: _endTime != null ? _formatTime(_endTime!) : null,
      recurrenceType: _recurrenceType,
      recurrenceDate: _buildRecurrenceData(),
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      reminderOffsets: _reminderOffsets,
      isAlarm: _isAlarm,
      alarmSound: _isAlarm ? (_alarmSoundId ?? AlarmSoundService.defaultSoundId) : null,
      snoozeMinutes: _snoozeMinutes,
      isActive: widget.existingTask?.isActive ?? true,
      createdAt: widget.existingTask?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final notifier = ref.read(taskProvider);
      if (_isEditing) {
        await notifier.updateTask(task);
      } else {
        await notifier.addTask(task);
      }
      
      final subtasks = <Subtask>[];
      for (int i=0; i < _subtaskControllers.length; i++) {
        final title = _subtaskControllers[i].text.trim();
        if (title.isNotEmpty) {
          subtasks.add(
              Subtask(
                  id: '${task.id}_sub_$i', 
                  taskId: task.id, 
                  title: title,
                sortOrder: i,
              )
          );
        }
      }
      await notifier.saveSubtasks(task.id, subtasks);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit task' : 'New Task'),
        actions : [
          TextButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save' : 'Create', style: const TextStyle(fontWeight: FontWeight.w600),),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g Morning Workout',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16,),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional notes...',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            
            _sectionTitle('Checklist'),
            const SizedBox(height: 8),
            ..._buildSubtaskFields(),
            TextButton.icon(
                onPressed: () {
                  setState(() {
                    _subtaskControllers.add(TextEditingController());
                  });
                }, 
                icon: const Icon(Icons.add, size: 18,),
                label: const Text('Add Step'),
            ),
            const SizedBox(height: 24),

            // Category
            _sectionTitle('Category'),
            const SizedBox(height: 8,),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in categories)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 16, color: cat.color,),
                        const SizedBox(width: 6,),
                        Text(cat.name),
                      ],
                    ),
                    selected: _categoryId == cat.id,
                    onSelected: (selected) {
                      setState(() => _categoryId = selected ? cat.id : null);
                    },
                  ),
              ],
            ),

            const SizedBox(height: 24,),

            // Priority
            _sectionTitle('Priority'),
            const SizedBox(height: 8,),
            SegmentedButton<TaskPriority>(
                segments: TaskPriority.values.map((p) => ButtonSegment(value: p, label: Text(p.label))).toList(),
                selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 24),

            // Time
            _sectionTitle('Time'),
            const SizedBox(height: 8,),
            Row(
              children: [
                Expanded(child:
                  _timePicker(
                    label: 'Start Time',
                    value: _startTime,
                    onChanged: (t) => setState(() => _startTime = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timePicker(
                    label: 'End Time',
                    value: _endTime,
                    onChanged: (t) => setState(() => _endTime = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24,),

            // Recurrence
            _sectionTitle('Recurrence'),
            const SizedBox(height: 8,),
            DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrenceType,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: RecurrenceType.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                onChanged: (v) => setState(() => _recurrenceType = v!),
            ),
            const SizedBox(height: 12),

            // Recurrence options
            _buildRecurrenceOptions(),
            const SizedBox(height: 16,),

            // Start date
            _datePicker(
              label: 'Start date',
              value: _startDate,
              onChanged: (d) { if (d != null) setState(() => _startDate = d); },
            ),
            const SizedBox(height: 12,),
            _datePicker(
              label: 'End Date (optional)',
              value: _endDate,
              onChanged: (d) => setState(() => _endDate = d),
              clearable: true,
            ),
            const SizedBox(height: 24,),

            // Reminders
            _sectionTitle('Reminders'),
            const SizedBox(height: 8,),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.reminderOffsetOptions.map((offset) {
                final selected = _reminderOffsets.contains(offset);
                return FilterChip(
                    label: Text(AppConstants.reminderOffSetLabel(offset)),
                    selected: selected,
                    onSelected: (s) {
                      setState(() {
                        if(s) {
                          _reminderOffsets.add(offset);
                        } else {
                          _reminderOffsets.remove(offset);
                        }
                      });
                    }
                );
              }).toList(),
            ),
            const SizedBox(height: 24,),

            // Alarm
            _sectionTitle('Alarm'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Ring alarm'),
              subtitle: const Text('Full-screen alarm with sound'),
              value: _isAlarm,
              onChanged: (v) => setState(() {
                _isAlarm = v;
                if (v && _alarmSoundId == null) {
                  _alarmSoundId = AlarmSoundService.defaultSoundId;
                }
              }),
              contentPadding: EdgeInsets.zero,
            ),

            if(_isAlarm) ...[
              const SizedBox(height: 8,),
              _buildAlarmSoundPicker(),
              const SizedBox(height: 12,),
              DropdownButtonFormField<int>(
                  initialValue: _snoozeMinutes,
                  decoration: const InputDecoration(labelText: 'Snooze duration'),
                  items: [5, 10, 15, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m minutes'))).toList(),
                onChanged: (v) => setState(() => _snoozeMinutes = v!),
              ),
            ],

            const SizedBox(height: 40,),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmSoundPicker() {
    final selectedSound = _availableSounds.isEmpty
        ? null
        : _availableSounds.cast<AlarmSound>().firstWhere(
        (s) => s.id == _alarmSoundId,
        orElse: () => _availableSounds.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
            initialValue: selectedSound?.id ?? AlarmSoundService.defaultSoundId,
            decoration: const InputDecoration(labelText: 'Alarm sound'),
        items: [
          ..._availableSounds.map((s) => DropdownMenuItem(
              value: s.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.isBuiltIn ? Icons.music_note : Icons.upload_file,
                  size: 18,
                  ),
                  const SizedBox(width: 8,),
                  Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis,)),
                ],
              ),
            ),
          ),
        ],
          onChanged: (v) => setState(() => _alarmSoundId = v),
        ),
        const SizedBox(height: 8,),
        Row(
          children: [
            OutlinedButton.icon(
                icon: Icon(
                  _soundService.isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(_soundService.isPlaying ? 'Stop' : 'Preview'),
                onPressed: selectedSound == null ? null : () async {
                  await _soundService.previewSound(selectedSound);
                  setState(() {});
                },
            ),
            const SizedBox(width: 8,),
            Row(
              children: [
                OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18,),
                    label: const Text('Upload sound'),
                    onPressed: () async {
                      final picked = await _soundService.pickAudioFile();
                      if (picked == null || !mounted) return;

                      final trimResult = await Navigator.of(context).push<AudioTrimResult>(
                        MaterialPageRoute(
                          builder: (_) => AudioTrimScreen(
                              filePath: picked.path,
                              fileName: picked.name
                          ),
                        ),
                      );

                      if(trimResult == null || !mounted) return;

                      final sound = await _soundService.trimAndSave(
                        sourcePath: picked.path,
                        fileName: picked.name,
                        startSec: trimResult.startSec,
                        endSec: trimResult.endSec,
                      );

                      if (sound != null) {
                        await _loadAvailableSounds();
                        setState(() => _alarmSoundId = sound.id);
                      }
                    }),
              ],
            ),
          ],
        ),
        // Delete custom sound button
        if (selectedSound != null && !selectedSound.isBuiltIn)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18,),
              label: Text('Remove "${selectedSound.name}"'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                await _soundService.deleteCustomSound(selectedSound.id);
                setState(() => _alarmSoundId = AlarmSoundService.defaultSoundId);
                await _loadAvailableSounds();
                },
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _timePicker({
    required String label, required TimeOfDay? value, required ValueChanged<TimeOfDay?> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showTimePicker(
            context: context,
            initialTime: value ?? TimeOfDay.now(),
        );
        if(picked != null) onChanged(picked);
      },
      onLongPress: () => onChanged(null),
      child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: value != null ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
            )
                : const Icon(Icons.access_time),
          ),
        child: Text(
          value != null ? value.format(context) : 'Not set',
          style: TextStyle(
            color: value != null ? null : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool clearable = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate : DateTime(2026),
            lastDate: DateTime(2099),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clearable && value != null
                ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
            )
                : const Icon(Icons.calendar_today),
          ),
        child: Text(
          value != null
              ? DateFormat('EEE, d MMM yyyy').format(value)
              : 'Not set',
          style: TextStyle(
            color: value != null ? null : Theme.of(context).colorScheme.outline
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceOptions() {
    switch(_recurrenceType) {
      case RecurrenceType.oneTime:
      case RecurrenceType.daily:
      case RecurrenceType.yearly:
        return const SizedBox.shrink();

      case RecurrenceType.specificDays:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            final day = i + 1; // 1=Mon, 7=Sun
            final selected = _selectedDay.contains(day);
            return FilterChip(
                label: Text(AppConstants.weekdayNames[i]),
              selected: selected,
              onSelected: (s) {
                  setState(() {
                    if (s) {
                      _selectedDay.add(day);
                    } else {
                      _selectedDay.remove(day);
                    }
                  });
              },
            );
          }),
        );

      case RecurrenceType.weekly:
      case RecurrenceType.biweekly:
        return DropdownButtonFormField<int>(
          initialValue: _weekday,
          decoration: const InputDecoration(labelText: 'Day of week'),
          items: List.generate(7, (i) {
            return DropdownMenuItem(
              value: i+1,
              child: Text(AppConstants.weekdaysFullNames[i]),
            );
          }),
          onChanged: (v) => setState(() => _weekday = v!),
        );

      case RecurrenceType.monthlyDate:
      case RecurrenceType.quarterly:
        return DropdownButtonFormField<int>(
          initialValue: _dayOfMonth.clamp(1, 31),
          decoration: const InputDecoration(labelText: 'Day of month'),
          items: List.generate(31, (i) {
            return DropdownMenuItem(value: i+1, child: Text('${i + 1}'));
          }),
          onChanged: (v) => setState(() => _dayOfMonth = v!),
        );

      case RecurrenceType.monthlyOrdinal:
        return Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: _ordinal.clamp(1, 5),
              decoration: const InputDecoration(labelText: 'which occurrence'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('First')),
                DropdownMenuItem(value: 2, child: Text('Second')),
                DropdownMenuItem(value: 3, child: Text('Third')),
                DropdownMenuItem(value: 4, child: Text('Fourth')),
                DropdownMenuItem(value: 5, child: Text('Fifth')),
              ],
              onChanged: (v) => setState(() => _ordinal = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Day of week'),
              items: List.generate(7, (i) {
                return DropdownMenuItem(
                    value: i + 1,
                    child: Text(AppConstants.weekdaysFullNames[i])
                );
              }),
              onChanged: (v) => setState(() => _weekday = v!),
            ),
          ],
        );

      case RecurrenceType.customInterval:
        return TextFormField(
          initialValue: '$_intervalDays',
          decoration: const InputDecoration(
            labelText: 'Repeat every N days',
            suffixText: 'days',
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) _intervalDays = n;
          },
        );
    }
  }

  List<Widget> _buildSubtaskFields() {
    return List.generate(_subtaskControllers.length, (index) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.drag_handle, size: 20, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                    controller: _subtaskControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Stop ${index + 1}',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
              ),
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _subtaskControllers[index].dispose();
                      _subtaskControllers.removeAt(index);
                    });
                  },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
      );
    });
  }
}