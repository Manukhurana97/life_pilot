import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:life_pilot/models/task.dart';
import 'package:life_pilot/models/category.dart';
import 'package:life_pilot/models/task_log.dart';
import 'package:life_pilot/models/subtask.dart';

class AppDatabase{
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final  path = join(dbPath, 'life_pilot.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        icon_code_point INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category_id TEXT,
        priority INTEGER DEFAULT 1,
        start_time TEXT,
        end_time TEXT,
        recurrent_type TEXT NOT NULL DEFAULT 'oneTime',
        recurrence_date TEXT DEFAULT '{}',
        start_date TEXT NOT NULL,
        end_date TEXT,
        reminder_offset TEXT DEFAULT '[]',
        is_alarm INTEGER DEFAULT 0,
        alarm_sound TEXT,
        snooze_minutes INTEGER DEFAULT 5,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE task_logs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        skip_reason TEXT,
        notes TEXT,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_logs_task_date ON task_logs(task_id, date);
    ''');

    await db.execute('''
      CREATE INDEX idx_tasks_Active ON tasks(is_active);
    ''');

    await db.execute(''' 
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(''' 
      CREATE INDEX idx_subtasks_task ON subtasks(task_id)
     ''');

    for(final cat in TaskCategory.defaults()){
      await db.insert('categories', cat.toMap());
    }
  }

  // -- Migrations --

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(''' 
        CREATE TABLE subtasks (
          id TEXT PRIMARY KEY,
          task_id TEXT NOT NULL,
          title TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          FOREIGN KEY (task_id) REFERENCE tasks (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_subtasks_task ON subtasks(task_id)');
    }
  }

  // Categories
  
  Future<List<TaskCategory>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC');
    return maps.map((m) => TaskCategory.fromMap(m)).toList();
  }

  Future<void> insertCategory(TaskCategory category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(TaskCategory category) async {
    final db = await database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // -- Tasks --

  Future<List<Task>> getTasks({bool? activeOnly}) async {
    final db = await database;
    String? where;
    List<Object>? whereArgs;
    if(activeOnly == true){
      where = 'is_active = ?';
      whereArgs = [1];
    }
    
    final maps = await db.query('tasks', where: where, whereArgs: whereArgs, 
       orderBy: 'created_at DESC');
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<Task?> getTask(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update('tasks', task.toMap(), 
      where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('task_logs', where: 'task_id = ?', whereArgs: [id]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // -- Task Logs --

  Future<List<TaskLog>> getLogsForTask(String taskId) async {
    final db = await database;
    final maps = await db.query('task_logs', 
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'date DESC');
    return maps.map((m) => TaskLog.fromMap(m)).toList();
  }

  Future<List<TaskLog>> getLogsForDate(String date) async {
    final db = await database;
    final maps = await db.query('task_logs', 
        where: 'date = ?', whereArgs: [date]);
    return maps.map((m) => TaskLog.fromMap(m)).toList();
  }

  Future<List<TaskLog>> getLogsBetween(String startDate, String endDate) async {
    final db = await database;
    final maps = await db.query('task_logs', 
        where: 'date >= ? AND date <= ?', 
        whereArgs: [startDate, endDate], 
        orderBy: 'date DESC');
    return maps.map((m) => TaskLog.fromMap(m)).toList();
  }

  Future<TaskLog?> getLogForTaskOnDate(String taskId, String date) async {
    final db = await database;
    final maps = await db.query('task_logs', 
        where: 'task_id = ? AND date = ?', whereArgs: [taskId, date]);
    if (maps.isEmpty) return null;
    return TaskLog.fromMap(maps.first);
  }

  Future<void> insertLog(TaskLog log) async {
    final db = await database;
    await db.insert('task_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await database;
    await db.delete('task_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteLogsForTaskOnDate(String taskId, String date) async {
    final db = await database;
    await db.delete('task_logs', 
      where: 'task_id = ? AND date = ?', whereArgs: [taskId, date]);
  }

  // -- Stats Queries --

  Future<int> getStreakForTask(String taskId) async {
    final db = await database;
    final logs = await db.query('task_logs', 
        where: 'task_id = ? AND status = ?', 
        whereArgs: [taskId, 'done'],
        orderBy: 'date DESC');
    if(logs.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    for(int i = 0; i<logs.length; i++){
      final logDate = DateTime.parse(logs[i]['date'] as String);
      final logDateNorm = DateTime(logDate.year, logDate.month, logDate.day);

      if(i == 0) {
        // Most recent log must be today or  yesterday to have an active streak
        final diff = todayNorm.difference(logDateNorm).inDays;
        if(diff > 1) return 0;
        streak = 1;
      } else {
        final prevDate = DateTime.parse(logs[i-1]['date'] as String);
        final prevDataNorm = DateTime(prevDate.year, prevDate.month, prevDate.day);
        final diff = prevDataNorm.difference(logDateNorm).inDays;
        if(diff == 1){
          streak++;
        } else {
          break;
        }
      }
    }

    return streak;
  }

  Future<int> getBestStreakForTask(String taskId) async {
    final db = await database;
    final logs = await db.query('task_logs', 
        where: 'task_id = ? AND status = ?', 
        whereArgs: [taskId, 'done'],
        orderBy: 'date DESC');
    if(logs.isEmpty) return 0;

    int bestStreak = 1;
    int currentStreak = 1;

    for(int i = 1; i<logs.length; i++){
        final prevDate = DateTime.parse(logs[i-1]['date'] as String);
        final currDate = DateTime.parse(logs[i]['date'] as String);
        final diff = prevDate.difference(currDate).inDays;


      if(diff == 1){
        currentStreak++;
        if(currentStreak > bestStreak) bestStreak = currentStreak;
      } else if(diff > 1){
        currentStreak = 1;
      }
    }
    return bestStreak;
  }

  Future<Map<String, int>> getCompletionCountsForRange(
    String startDate, String endDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT date, COUNT(*) as count FROM task_logs
      WHERE date >= ? AND date <= ? AND status = 'done'
      GROUP BY date ORDER BY date
    ''', [startDate, endDate]);

    return {for (var r in result) r['date'] as String: r['count'] as int};
  }

  Future<int> getTotalCompletitions(String taskId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM task_logs WHERE task_id = ? AND status = ?'
    , [taskId, 'done']);

    return result.first['c'] as int;
  }

  // -- Subtasks --

  Future<List<Subtask>> getSubtasks(String taskId) async {
    final db = await database;
    final maps = await db.query('subtasks', where: 'task_id = ?', whereArgs: [taskId], orderBy: 'sort_order ASC');
    return maps.map((m) => Subtask.fromMap(m)).toList();
  }

  Future<void> insertSubtask(Subtask subtask) async {
    final db = await database;
    await db.insert('subtasks', subtask.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSubtask(Subtask subtask) async {
    final db = await database;
    await db.update('subtasks', subtask.toMap(), where: 'id = ?', whereArgs: [subtask.id]);
  }

  Future<void> deleteSubtask(String id) async {
    final db = await database;
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtaskForTask(String taskId) async {
    final db = await database;
    await db.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
  }

  Future<void> replaceSubtasks(String taskId, List<Subtask> subtasks) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
      for (final st in subtasks) {
        await txn.insert('subtasks', st.toMap());
      }
    });
  }

  Future<void> resetAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('subtasks');
      await txn.delete('task_logs');
      await txn.delete('tasks');
      await txn.delete('categories');

      for (final cat in TaskCategory.defaults()) {
        await txn.insert('categories', cat.toMap());
      }
    });
  }
}
