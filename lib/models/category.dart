import 'package:flutter/material.dart';

class TaskCategory {
  final String id;
  final String name;
  final int colorValue;
  final IconData icon;
  final int sortOrder;

  TaskCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.icon = Icons.category,
    this.sortOrder = 0,
  });

  Color get color => Color(colorValue);
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_code_point': icon.codePoint,
      'sort_order': sortOrder,
    };
  }

  factory TaskCategory.fromMap(Map<String, dynamic> map) {
    return TaskCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['color_value'] as int,
      icon: IconData(map['icon_code_point'] as int, fontFamily: 'MaterialIcons'),
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  TaskCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    IconData? icon,
    int? sortOrder,
  }) {
    return TaskCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static List<TaskCategory> defaults() {
    return [
      TaskCategory(id: 'health', name: 'Health', colorValue: 0xFF4CAF50, icon: Icons.monitor_heart, sortOrder: 0),
      TaskCategory(id: 'fitness', name: 'fitness', colorValue: 0xFFFF5722, icon: Icons.fitness_center, sortOrder: 0),
      TaskCategory(id: 'learning', name: 'learning', colorValue: 0xFF2196F3, icon: Icons.school, sortOrder: 0),
      TaskCategory(id: 'finance', name: 'finance', colorValue: 0xFF9C27B0, icon: Icons.savings, sortOrder: 0),
      TaskCategory(id: 'medical', name: 'medical', colorValue: 0xFF91E63, icon: Icons.medical_services, sortOrder: 0),
      TaskCategory(id: 'work', name: 'work', colorValue: 0xFFFF9800, icon: Icons.business_center, sortOrder: 0),
      TaskCategory(id: 'personal', name: 'personal', colorValue: 0xFF607D8B, icon: Icons.self_improvement, sortOrder: 0),
    ];
  }
}