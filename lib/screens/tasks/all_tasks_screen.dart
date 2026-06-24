import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/screens/task/task_form_screen.dart';
import 'package:life_pilot/screens/task/task_detail_screen.dart';

class AllTasksScreen extends ConsumerStatefulWidget {
  const AllTasksScreen({super.key});

  @override
  ConsumerState<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends ConsumerState<AllTasksScreen> {
  String? _filterCategory;
  bool _showPaused = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext content) {
    final theme = Theme.of(context);
    final taskNotifier = ref.watch(taskProvider);
    final categories = ref.watch(categoryProvider).categories;

    var tasks = List<Task>.from(taskNotifier.tasks);

    // Filter
    if (!_showPaused) {
      tasks = tasks.where((t) => t.isActive).toList();
    }

    if (_filterCategory != null) {
      tasks = tasks.where((t) => t.categoryId == _filterCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks.where((t) =>
          t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          IconButton(
            icon: Icon(_showPaused ? Icons.visibility : Icons.visibility_off, size: 22),
            tooltip: _showPaused ? 'Hide paused' : 'Show paused',
            onPressed: () => setState(() => _showPaused = !_showPaused),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                    onPressed: () => setState(() => _searchQuery = ''),
                    icon: const Icon(Icons.clear))
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                      label: const Text('All'),
                      selected: _filterCategory == null,
                    onSelected: (_) => setState(() => _filterCategory = null),
                  ),
                ),
                ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                      avatar: Icon(cat.icon, size: 16, color: cat.color),
                      label: Text(cat.name),
                      selected: _filterCategory == cat.id,
                      onSelected: (selected) {
                        setState(() =>
                        _filterCategory = selected ? cat.id : null);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1,),

          // Task List
          Expanded(
              child: tasks.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 12,),
                    Text('No tasks found', style: TextStyle(color: theme.colorScheme.outline)),
                  ],
                ),
              )
                  :ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final category = ref.watch(categoryProvider).getById(task.categoryId);
                  final streak = taskNotifier.getStreak(task.id);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 3
                    ),
                    child: Card(
                      child: ListTile(
                        leading: category != null ?
                        CircleAvatar(
                            backgroundColor: category.color.withValues(alpha: 0.15),
                            child: Icon(category.icon, color: category.color, size: 20))
                            : CircleAvatar(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.task, size: 20),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: task.isActive ? null : theme.colorScheme.outline,
                            decoration: task.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(task.recurrenceType.label, style: theme.textTheme.bodySmall),
                            if (task.startTime != null) ...[
                              const Text(' . '),
                              Text(task.startTime!, style: theme.textTheme.bodySmall),
                            ],
                            if (!task.isActive) ...[
                              const Text(' . '),
                              Text('Paused', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (streak > 0 && task.recurrenceType != RecurrenceType.oneTime)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('🔥 $streak', style: const TextStyle(fontSize: 12)),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20,),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: task.id),
                              ),
                          );
                        },
                      )
                    )
                  );
                },
              ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'allTasksFab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaskFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}