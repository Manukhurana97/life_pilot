import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/enums.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/screens/task/task_detail_screen.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final bool isDone;
  final bool isSkipped;
  final VoidCallback? onCompleted;
  final VoidCallback? onSkipped;
  final VoidCallback? onUndo;
  final int subtaskCount;
  final int checkedCount;

  const TaskCard({
    super.key,
    required this.task,
    this.isDone = false,
    this.isSkipped = false,
    this.onCompleted,
    this.onSkipped,
    this.onUndo,
    this.subtaskCount = 0,
    this.checkedCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final category = ref.watch(categoryProvider).getById(task.categoryId);
    final streak = ref.watch(taskProvider).getStreak(task.id);
    final isRecurring = task.recurrenceType != RecurrenceType.oneTime;
  
  
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key(task.id), 
        direction: isDone || isSkipped
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.green.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 28),
        ),  
        secondaryBackground : Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: isDone || isSkipped ? Colors.orange.shade400 : Colors.amber.shade400,
            borderRadius: BorderRadius.circular(16), 
          ),
          child: Icon(
            isDone || isSkipped ? Icons.undo : Icons.skip_next,
            color: Colors.white,
            size: 28,
          ),
        ),

        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onCompleted?.call();
          } else {
            if(isDone || isSkipped) {
              onUndo?.call();
            } else {
              onSkipped?.call();
            }
          }

          return false;
        },
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id)
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if(isDone || isSkipped) {
                        onUndo?.call();
                      } else {
                        onCompleted?.call();
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone 
                          ? theme.colorScheme.primary
                          : isSkipped ? theme.colorScheme.outline : Colors.transparent,
                        border: Border.all(
                          color: isDone ? theme.colorScheme.outline : isSkipped ? theme.colorScheme.outline : theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: isDone 
                        ? const Icon(Icons.check, size: 18, color: Colors.white) 
                        : isSkipped 
                          ? const Icon(Icons.remove, size: 18, color: Colors.white) 
                          : null, 
                    ),
                  ),

                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone || isSkipped ? theme.colorScheme.outline : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (task.startTime != null) ...[
                              Icon(Icons.access_time, size: 14, color: theme.colorScheme.outline),
                              const SizedBox(width: 4),
                              Text(
                                task.endTime != null ? '${task.startTime} - ${task.endTime}' : task.startTime!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (category != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: category.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ],
                        )
                      ],
                    ),
                  ),
                  //Streak & indicators
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isRecurring && streak > 0) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10), 
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '$streak',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if(subtaskCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$checkedCount/$subtaskCount',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: checkedCount == subtaskCount
                                  ? Colors.green
                                  : theme.colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      if(task.isAlarm) 
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.alarm, size: 16, color: theme.colorScheme.error)
                        ),
                      if(task.priority == TaskPriority.high) 
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.flag, size: 16, color: theme.colorScheme.error),
                        ),
                    ],
                  ),
                ],
              )
            ),
          ),
        )
      )
    );
  }
}