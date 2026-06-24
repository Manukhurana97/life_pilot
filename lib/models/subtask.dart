class Subtask {
  final String id;
  final String taskId;
  final String title;
  final int sortOrder;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'sortOrder': sortOrder,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
        id: map['id'] as String,
        taskId: map['task_id'] as String,
        title: map['title'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    int? sortOrder
  }) {
    return Subtask(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder
    );
  }
}
