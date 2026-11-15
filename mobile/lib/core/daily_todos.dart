import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Pastel colours for private daily items. Values are ARGB, independent of UI.
class DailyTodoColors {
  static const int pink = 0xFFFFD9E7;
  static const int peach = 0xFFFFE2D2;
  static const int lemon = 0xFFFFF0C6;
  static const int mint = 0xFFD8F3E5;
  static const int sky = 0xFFD8EBFF;
  static const int lilac = 0xFFE9DEFF;
  static const int defaultColor = pink;
  static const List<int> choices = [pink, peach, lemon, mint, sky, lilac];
}

/// A personal, date-specific item, intentionally unrelated to work tasks.
/// Time is optional. Without a start/end pair an item is an all-day item.
class DailyTodo {
  final String id;
  final String date;
  final String title;
  final String note;
  final bool completed;
  final int colorValue;
  final String? startTime; // local HH:mm
  final String? endTime;   // local HH:mm

  const DailyTodo({
    required this.id, required this.date, required this.title,
    this.note = '', this.completed = false,
    this.colorValue = DailyTodoColors.defaultColor,
    this.startTime, this.endTime,
  });

  static bool validTimeRange(String? start, String? end) {
    if (start == null && end == null) return true;
    if (start == null || end == null) return false;
    final pattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    return pattern.hasMatch(start) && pattern.hasMatch(end) &&
        end.compareTo(start) > 0;
  }

  String get timeLabel => startTime != null && endTime != null
      ? '$startTime–$endTime' : '全天';

  factory DailyTodo.fromJson(dynamic value) {
    final j = mapOf(value);
    final rawColor = j['colorValue'];
    final decodedColor = rawColor is int ? rawColor : int.tryParse('$rawColor');
    String? parseTime(dynamic value) => value is String && value.isNotEmpty
        ? value : null;
    final start = parseTime(j['startTime']);
    final end = parseTime(j['endTime']);
    return DailyTodo(
      id: textOf(j['id']), date: textOf(j['date']),
      title: textOf(j['title']), note: textOf(j['note']),
      completed: j['completed'] == true,
      colorValue: DailyTodoColors.choices.contains(decodedColor)
          ? decodedColor! : DailyTodoColors.defaultColor,
      startTime: validTimeRange(start, end) ? start : null,
      endTime: validTimeRange(start, end) ? end : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'title': title, 'note': note,
    'completed': completed, 'colorValue': colorValue,
    'startTime': startTime, 'endTime': endTime,
  };

  DailyTodo copyWith({
    String? date, String? title, String? note, bool? completed,
    int? colorValue, String? startTime, String? endTime,
    bool clearTime = false,
  }) => DailyTodo(
    id: id, date: date ?? this.date, title: title ?? this.title,
    note: note ?? this.note, completed: completed ?? this.completed,
    colorValue: colorValue ?? this.colorValue,
    startTime: clearTime ? null : (startTime ?? this.startTime),
    endTime: clearTime ? null : (endTime ?? this.endTime),
  );
}

/// Moves one private todo across calendar dates. Keeps its ID, color, time,
/// completion state, and the order of every other item exactly unchanged.
/// Unknown IDs and invalid target dates are treated as no-ops.
List<DailyTodo> moveDailyTodoToDate(
    List<DailyTodo> items, String itemId, String targetDate) {
  final parsed = DateTime.tryParse(targetDate);
  if (parsed == null || dayString(parsed) != targetDate) return [...items];
  return [for (final item in items)
    if (item.id == itemId && item.date != targetDate)
      item.copyWith(date: targetDate)
    else
      item];
}

/// Reorders only items on the selected date; records on other dates are intact.
/// newIndex is already adjusted by ReorderableListView.onReorderItem.
List<DailyTodo> reorderDailyTodosForDay(
    List<DailyTodo> items, String date, int oldIndex, int newIndex) {
  final dayItems = items.where((item) => item.date == date).toList();
  if (oldIndex < 0 || oldIndex >= dayItems.length ||
      newIndex < 0 || newIndex >= dayItems.length) {
    return [...items];
  }
  final moved = dayItems.removeAt(oldIndex);
  dayItems.insert(newIndex, moved);
  var next = 0;
  return [for (final item in items)
    if (item.date == date) dayItems[next++] else item];
}

class DailyTodoStorage {
  final int userId;
  const DailyTodoStorage(this.userId);
  // Keep the original key so old private tasks survive an APK upgrade.
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
    final ok = await prefs.setString(_key,
        jsonEncode(items.map((e) => e.toJson()).toList()));
    if (!ok) throw StateError('保存每日事项失败');
  }
}
