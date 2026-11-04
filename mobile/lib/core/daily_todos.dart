import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// A personal, date-specific item. It is intentionally unrelated to company
/// task assignments, task approvals and work logs.
class DailyTodo {
  final String id;
  final String date;
  final String title;
  final String note;
  final bool completed;

  const DailyTodo({required this.id, required this.date, required this.title,
    this.note = '', this.completed = false});

  factory DailyTodo.fromJson(dynamic value) {
    final j = mapOf(value);
    return DailyTodo(
      id: textOf(j['id']), date: textOf(j['date']),
      title: textOf(j['title']), note: textOf(j['note']),
      completed: j['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'title': title, 'note': note,
    'completed': completed,
  };

  DailyTodo copyWith({String? date, String? title, String? note, bool? completed}) =>
    DailyTodo(id: id, date: date ?? this.date, title: title ?? this.title,
      note: note ?? this.note, completed: completed ?? this.completed);
}

class DailyTodoStorage {
  final int userId;
  const DailyTodoStorage(this.userId);
  String get _key => 'pandora_daily_todos_v1_$userId';

  Future<List<DailyTodo>> read() async {
    if (userId <= 0) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) throw const FormatException('非数组结构');
      return values.map(DailyTodo.fromJson).where((item) =>
        item.id.isNotEmpty && DateTime.tryParse(item.date) != null &&
        item.title.trim().isNotEmpty).toList();
    } catch (_) {
      throw const FormatException('每日事项本地记录读取失败，请先备份数据，不会自动覆盖');
    }
  }

  Future<void> write(List<DailyTodo> items) async {
    if (userId <= 0) throw StateError('未登录，不能保存每日事项');
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    if (!ok) throw StateError('保存每日事项失败');
  }
}
