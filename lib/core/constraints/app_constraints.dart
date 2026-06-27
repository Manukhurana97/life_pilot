class AppConstants {
  static const String appName = 'LifePilot';
  static const String appVersion = '1.0.0';

  static const List<String> weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  static const List<String> weekdaysFullNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static const List<String> monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<int> reminderOffsetOptions = [
    0, 5, 10, 15, 20, 30, 60, 1440 // 0 = at time, 1440 = 1 day before
  ];

  static String reminderOffSetLabel(int minutes) {
    if (minutes == 0) return 'At time';
    if (minutes < 60) return '$minutes min before';
    if (minutes == 60) return '1 hour before';
    if (minutes == 1440) return '1 day before';
    if (minutes < 1440) return '${minutes ~/ 60} hours before';
    return '${minutes ~/ 1440} days before';
  }
}
