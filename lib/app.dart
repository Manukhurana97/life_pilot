import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/core/theme/app_theme.dart';
import 'package:life_pilot/core/constraints/app_constraints.dart';
import 'package:life_pilot/providers/settings_provider.dart';
import 'package:life_pilot/screens/home/home_screen.dart';
import 'package:life_pilot/screens/calendar/calendar_screen.dart';
import 'package:life_pilot/screens/splash/splash_screen.dart';
import 'package:life_pilot/screens/tasks/all_tasks_screen.dart';
import 'package:life_pilot/screens/stats/stats_screen.dart';
import 'package:life_pilot/services/notification_service.dart';


class DayPilotApp extends ConsumerWidget {
  const DayPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const SplashScreen(child: AppShell()),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _notificationService = NotificationService();

  static const _accentColor = Color(0xFFFF6B35);
  static const _accentColorLight = Color(0xFFFFF0E8);

  final _screens = const [
    HomeScreen(),
    CalendarScreen(),
    AllTasksScreen(),
    StatsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService.startAlarmPolling();
    _notificationService.handlePendingAlarm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.stopAlarmPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notificationService.startAlarmPolling();
    } else if (state == AppLifecycleState.paused) {
      _notificationService.stopAlarmPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.today_outlined, Icons.today, 'Today', isDark),
                  _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'Calender', isDark),
                  _buildNavItem(2, Icons.list_alt_outlined, Icons.list_alt, 'Tasks', isDark),
                  _buildNavItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Stats', isDark),
                ],
              ),
            ),
        )
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? _accentColor.withValues(alpha: 0.15): _accentColorLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected
                  ? _accentColor
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
