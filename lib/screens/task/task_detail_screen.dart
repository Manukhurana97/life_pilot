import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/models/task_log.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/screens/task/task_form_screen.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  List<TaskLog> _logs = [];
  int _bestStreak = 0;
  int _totalCompletions = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final notifier = ref.read(taskProvider);
    _logs = await notifier.getLogsForTask(widget.taskId);
    _bestStreak = await notifier.getBestStreak(widget.taskId);
    _totalCompletions = await notifier.getTotalCompletitions(widget.taskId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskNotifier = ref.watch(taskProvider);
    final task = taskNotifier.tasks
        .where((t) => t.id == widget.taskId)
        .firstOrNull;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    final category = ref.watch(categoryProvider).getById(task.categoryId);
    final streak = taskNotifier.getStreak(task.id);
    final log = taskNotifier.getLogForTask(task.id);
    final isRecurring = task.recurrenceType != RecurrenceType.oneTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(existingTask: task),
                ),
              );
              _loadStats();
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: Icon(
                    task.isActive ? Icons.pause : Icons.play_arrow,
                    size: 20,
                  ),
                  title: Text(task.isActive ? 'Pause' : 'Resume'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                onTap: () => taskNotifier.toggleActive(task.id),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.delete, size: 20, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Task'),
                      content: const Text(
                        'This will permanently delete this task and all its history',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await taskNotifier.deleteTask(task.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title & status
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!task.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Paused',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if(category != null)
                Chip(
                  avatar: Icon(category.icon, size: 16, color: category.color,),
                  label: Text(category.name),
                ),
              Chip(
                  avatar: const Icon(Icons.repeat, size: 16,),
                  label: Text(task.recurrenceType.label),
              ),
              Chip(
                avatar: const Icon(Icons.flag, size: 16,),
                label: Text(task.priority.label),
              ),
              if (task.startTime != null)
                Chip(
                  avatar: const Icon(Icons.access_time, size: 16),
                  label: Text(task.endTime != null
                      ? '${task.startTime} - ${task.endTime}'
                      : task.startTime!),
                ),
              if(task.isAlarm)
                Chip(
                  avatar: Icon(Icons.alarm, size: 16, color: theme.colorScheme.error,),
                  label: const Text('Alarm'),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Today's action
          if (task.isActive) ...[
            if (log == null)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        taskNotifier.markDone(task.id);
                        _loadStats();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showSkipDialog(taskNotifier, task.id),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                  ),
                ],
              )
            else
              Card(
                color: log.status == TaskLogStatus.done
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                child: ListTile(
                  leading: Icon(
                    log.status == TaskLogStatus.done
                        ? Icons.check_circle
                        : Icons.skip_next,
                    color: log.status == TaskLogStatus.done
                        ? Colors.green
                        : Colors.amber.shade700,
                  ),
                  title: Text(
                    log.status == TaskLogStatus.done
                        ? 'Completed today'
                        : 'Skipped today',
                  ),
                  subtitle: log.skipReason != null
                      ? Text('Reason: ${log.skipReason}')
                      : null,
                  trailing: TextButton(
                    onPressed: () {
                      taskNotifier.undoLog(task.id);
                      _loadStats();
                    },
                    child: const Text('Undo'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Stats
          if (isRecurring) ...[
            _sectionTitle('Statistics'),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(theme, '🔥 Streak', '$streak days'),
                const SizedBox(width: 12),
                _statCard(theme, '🏆 Best', '$_bestStreak days'),
                const SizedBox(width: 12),
                _statCard(theme, '✅ Total', '$_totalCompletions'),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // History
          _sectionTitle('Recent History'),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            Text(
              'No history yet',
              style: TextStyle(color: theme.colorScheme.outline),
            )
          else
            ...(_logs
                .take(20)
                .map(
                  (log) => ListTile(
                    dense: true,
                    leading: Icon(
                      log.status == TaskLogStatus.done
                          ? Icons.check_circle
                          : log.status == TaskLogStatus.skipped
                          ? Icons.skip_next
                          : Icons.cancel,
                      color: log.status == TaskLogStatus.done
                          ? Colors.green
                          : log.status == TaskLogStatus.skipped
                          ? Colors.amber
                          : Colors.red,
                      size: 20,
                    ),
                    title: Text(
                      DateFormat(
                        'EEE d MMM yyyy',
                      ).format(DateTime.parse(log.date)),
                    ),
                    subtitle: log.skipReason != null
                        ? Text(log.skipReason!)
                        : null,
                    trailing: Text(
                      log.status.name.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSkipDialog(TaskNotifier notifier, String taskId) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Travelling',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.markSkipped(
                taskId,
                reason: controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim(),
              );
              Navigator.pop(ctx);
              _loadStats();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}
