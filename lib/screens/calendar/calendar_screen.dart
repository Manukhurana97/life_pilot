import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/providers/task_provider.dart';
import 'package:life_pilot/providers/category_provider.dart';
import 'package:life_pilot/screens/task/task_detail_screen.dart';

class CalenderScreen extends ConsumerStatefulWidget {
  const CalenderScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CalenderScreenState();
}

class _CalenderScreenState extends ConsumerState<CalenderScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskNotifier = ref.watch(taskProvider);
    final selectedTasks = taskNotifier.getTasksDueOn(_selectedDay);

    // Sort by time
    selectedTasks.sort((a, b) {
      final aTime = a.startTime ?? '99.99';
      final bTime = b.startTime ?? '99.99';

      return aTime.compareTo(bTime);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calender'),
        actions: [
          IconButton(onPressed: () {
            setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            });
          }, icon: const Icon(Icons.today))
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020), 
            lastDay: DateTime(2099), 
            focusedDay: _focusedDay, 
            calendarFormat: _calendarFormat, 
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day), 
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay  = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged : (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              return taskNotifier.getTasksDueOn(day);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            
              todayTextStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              markerSize: 4,
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsetsGeometry.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(_selectedDay),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${selectedTasks.length} tasks',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: selectedTasks.isEmpty
                ? Center(
                  child: Text(
                    "No Task on this day",
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final task = selectedTasks[index];
                    final category = ref.watch(categoryProvider).getById(task.categoryId); 

                    return Card(
                      child: ListTile(
                        leading: category != null 
                            ? CircleAvatar(
                              backgroundColor: category.color.withValues(alpha: 0.15),
                              child: Icon(category.icon, color: category.color, size: 20),
                            )
                            : null,
                        title: Text(task.title),
                        subtitle: task.startTime != null ? Text(task.endDate != null ? '${task.startTime} - ${task.endTime}' : task.startTime!) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if(task.isAlarm) 
                              Icon(Icons.alarm, size: 16, color: theme.colorScheme.error),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}