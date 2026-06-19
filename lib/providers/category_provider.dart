import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_pilot/database/app_database.dart';
import 'package:life_pilot/models/category.dart';

final categoryProvider = ChangeNotifierProvider<CategoryNotifier>((ref) {
  return CategoryNotifier();
});

class CategoryNotifier extends ChangeNotifier {
  final AppDatabase db = AppDatabase();

  List<TaskCategory> _categories = [];
  bool _isLoading = false;

  List<TaskCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  TaskCategory? getById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    _categories = await db.getCategories();

    if(_categories.isEmpty) {
      for (final cat in TaskCategory.defaults()) {
        await db.insertCategory(cat);
      }
      _categories = await db.getCategories();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(TaskCategory category) async {
    await db.insertCategory(category);
    _categories.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(TaskCategory category) async {
    await db.updateCategory(category);
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1)  _categories[index] = category;
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await db.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}