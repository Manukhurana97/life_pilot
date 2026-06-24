import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StateScreenState();
}

class _StateScreenState extends ConsumerState<StatsScreen> {
  final AppDatabase _db = AppDatabase();
  Map<String, int> _weeklyData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 6));
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      final endStr = DateFormat('yyyy-MM-dd').format(now);

      _weeklyData = await _db.getCompletionCountsForRange(startStr, endStr);
    } catch (e) {
      debugPrint('Error loading weekly data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskNotifier = ref.watch(taskProvider);
    final categories = ref.watch(categoryProvider).categories;

    final activeTasks = taskNotifier.activeTasks;
    final todayTasks = taskNotifier.todayTasks;
    final todayDone = todayTasks.where((t) {
      final log = taskNotifier.getLogForTask(t.id);
      return log?.status == TaskLogStatus.done;
    }).length;

    // Per-category task counts
    final categoryCounts = <String, int>{};
    for (final task in activeTasks) {
      final catId = task.categoryId ?? 'uncategorized';
      categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
        children: [
          // Summary cards
          Row(
            children: [
              _summaryCard(theme, 'Today', '$todayDone / ${todayTasks.length}', Icons.today),
              const SizedBox(width: 12),
              _summaryCard(theme, 'Active Tasks', '${activeTasks.length}', Icons.task_alt),
              const SizedBox(width: 12),
              _summaryCard(theme, 'Total', '${taskNotifier.tasks.length}', Icons.list),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 20,),

          //  Weekly chart
          Text('Last 7 days',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildWeeklyChart(theme),
          ),
          const SizedBox(height: 28,),

          // Top streaks
          Text('Top Streaks', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          ..._buildStreakList(theme, taskNotifier),
          const SizedBox(height: 28,),

          // Category breakdown
          Text('Tasks by category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...categoryCounts.entries.map((entry) {
            final cat = categories.where((c) => c.id == entry.key).firstOrNull;
            final name = cat?.name ?? 'Uncategorized';
            final color = cat?.color ?? theme.colorScheme.outline;
            
            return Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10,),
                    Expanded(child: Text(name)),
                    Text('${entry.value} tasks', style: theme.textTheme.bodySmall,),
                  ],
                ),
            );
          }),
          const SizedBox(height: 40,),
        ],
      )
    );
  }

  Widget _summaryCard(ThemeData theme, String label, String value, IconData icon) {
    return Expanded(
        child: Card(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
              child: Column(
                children: [
                  Icon(icon, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(height: 8,),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2,),
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center,),
                ],
              )
          ),
        ),
    );
  }

  Widget _buildWeeklyChart(ThemeData theme) {
    final now = DateTime.now();
    final bars = <BarChartGroupData>[];

    for (int i=6; i>=0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final count = _weeklyData[dateStr] ?? 0;

      bars.add(BarChartGroupData(
          x: 6 - i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: theme.colorScheme.primary,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      ));
    }

    return BarChart(
      BarChartData(
        barGroups: bars,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = now.subtract(Duration(days: 6 - value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('E').format(day),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, index) {
              return BarTooltipItem(
                '${rod.toY.toInt()} done',
                TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12),
              );
            }
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStreakList(ThemeData theme, TaskNotifier taskNotifier) {
    final streakTasks = taskNotifier.activeTasks
        .where((t) => t.recurrenceType != RecurrenceType.oneTime)
        .map((t) => MapEntry(t, taskNotifier.getStreak(t.id)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (streakTasks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No active streaks yet', style: TextStyle(color: theme.colorScheme.outline)),
        )
      ];
    }

    return streakTasks.take(10).map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Card(
          child: ListTile(
            dense: true,
            leading: const Text('', style: TextStyle(fontSize: 20),),
            title: Text(entry.key.title),
            trailing: Text('${entry.value} day',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }).toList();
  }
}