import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/screens/home/widgets/task_card.dart';
import 'package:life_pilot/screens/settings/settings_screen.dart';
import 'package:life_pilot/screens/task/task_form_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider).loadTasks();
      ref.read(categoryProvider).loadCategories();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final taskNotifier = ref.watch(taskProvider);
    final settings = ref.watch(settingsProvider);
    final todayTasks = List<Task>.from(taskNotifier.todayTasks);
    final theme = Theme.of(context);

    // Sort by time
    todayTasks.sort((a, b) {
      final aTime = a.startTime ?? '99.99';
      final bTime = b.startTime ?? '99.99';
      return aTime.compareTo(bTime);
    });

    // Separate into groups
    final pending = <Task>[];
    final completed = <Task>[];
    final skipped = <Task>[];

    for (final task in todayTasks) {
      final log = taskNotifier.getLogForTask(task.id);
      if (log == null) {
        pending.add(task);
      } else if (log.status == TaskLogStatus.done) {
        completed.add(task);
      } else {
        skipped.add(task);
      }
    }

    final timedPending = pending.where((t) => t.startTime != null).toList();
    final untimedPending = pending.where((t) => t.startTime == null).toList();

    final totalTasks = todayTasks.length;
    final doneCount = completed.length;

    return Scaffold(
      body: taskNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => taskNotifier.loadTasks(),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 100,
                    floating: true,
                    pinned: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        padding: const EdgeInsets.fromLTRB(20, 54, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, d MMMM').format(DateTime.now()),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Progress bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$doneCount of $totalTasks tasks done',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (totalTasks > 0)
                                Text(
                                  '${(doneCount / totalTasks * 100).round()}%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadiusGeometry.circular(6),
                            child: LinearProgressIndicator(
                              value: totalTasks > 0
                                  ? doneCount / totalTasks
                                  : 0,
                              minHeight: 8,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (timedPending.isNotEmpty) ...[
                    _sectionHeader(context, 'Schedule', timedPending.length),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTimelineItem(
                          context,
                          task: timedPending[index],
                          isFirst: index == 0,
                          isLast: index == timedPending.length - 1,
                          taskNotifier: taskNotifier,
                        ),
                        childCount: timedPending.length,
                      ),
                    ),
                  ],
                  if (untimedPending.isNotEmpty) ...[
                    _sectionHeader(context, 'Anytime', untimedPending.length),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => TaskCard(
                          task: untimedPending[index],
                          onCompleted: () =>
                              taskNotifier.markDone(untimedPending[index].id),
                          onSkipped: () => taskNotifier.markSkipped(
                            untimedPending[index].id,
                          ),
                          subtaskCount: taskNotifier.getSubtaskCount(
                            untimedPending[index].id,
                          ),
                          checkedCount: taskNotifier.getCheckedCount(
                            untimedPending[index].id,
                          ),
                        ),
                        childCount: untimedPending.length,
                      ),
                    ),
                  ],
                  // Completed tasks
                  if (completed.isNotEmpty && settings.showCompletedTasks) ...[
                    _sectionHeader(context, 'Completed', completed.length),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => TaskCard(
                          task: completed[index],
                          isDone: true,
                          onUndo: () =>
                              taskNotifier.undoLog(completed[index].id),
                          subtaskCount: taskNotifier.getSubtaskCount(
                            completed[index].id,
                          ),
                          checkedCount: taskNotifier.getCheckedCount(
                            completed[index].id,
                          ),
                        ),
                        childCount: completed.length,
                      ),
                    ),
                  ],
                  // Skipped tasks
                  if (skipped.isNotEmpty) ...[
                    _sectionHeader(context, 'Skipped', skipped.length),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => TaskCard(
                          task: skipped[index],
                          isSkipped: true,
                          onUndo: () => taskNotifier.undoLog(skipped[index].id),
                          subtaskCount: taskNotifier.getSubtaskCount(
                            skipped[index].id,
                          ),
                          checkedCount: taskNotifier.getCheckedCount(
                            skipped[index].id,
                          ),
                        ),
                        childCount: skipped.length,
                      ),
                    ),
                  ],
                  // Empty state
                  if (todayTasks.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 72,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks for today',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add a new task',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TaskFormScreen()));
            },
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required Task task,
    required bool isFirst,
    required bool isLast,
    required TaskNotifier taskNotifier,
  }) {
    final theme = Theme.of(context);

    TimeOfDay? startTod;
    if (task.startTime != null) {
      final parts = task.startTime!.split(':');
      startTod = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    TimeOfDay? endTod;
    if (task.endTime != null) {
      final parts = task.endTime!.split(':');
      endTod = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsetsGeometry.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    startTod?.format(context) ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (endTod != null)
                    Text(
                      endTod.format(context),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst
                      ? Colors.transparent
                      : theme.colorScheme.outlineVariant,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TaskCard(
              task: task,
              onCompleted: () => taskNotifier.markDone(task.id),
              onSkipped: () => taskNotifier.markSkipped(task.id),
              subtaskCount: taskNotifier.getSubtaskCount(task.id),
              checkedCount: taskNotifier.getCheckedCount(task.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
