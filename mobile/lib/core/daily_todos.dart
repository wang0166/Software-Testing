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
  final String? _endDate;
  String get endDate => _endDate ?? date;
  final String title;
  final String note;
  final bool completed;
  final int colorValue;
  final String? startTime; // local HH:mm
  final String? endTime;   // local HH:mm
  final int sortOrder;

  const DailyTodo({
    required this.id, required this.date, required this.title,
    String? endDate,
    this.note = '', this.completed = false,
    this.colorValue = DailyTodoColors.defaultColor,
    this.startTime, this.endTime,
    this.sortOrder = 0,
  }) : _endDate = endDate;

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

  static bool validDate(String date) {
    final parsed = DateTime.tryParse(date);
    return parsed != null && _datePattern.hasMatch(date) && dayString(parsed) == date;
  }

  static bool validTimeRange(String? start, String? end, {bool acrossDays = false}) {
    if (start == null || end == null) return start == null && end == null;
    return _timePattern.hasMatch(start) && _timePattern.hasMatch(end) &&
      (acrossDays || end.compareTo(start) > 0);
  }

  bool get hasValidRange => validDate(date) && validDate(endDate) &&
      endDate.compareTo(date) >= 0 &&
      validTimeRange(startTime, endTime, acrossDays: date != endDate);

  bool overlaps({String? from, String? to}) =>
      (from == null || endDate.compareTo(from) >= 0) &&
      (to == null || date.compareTo(to) <= 0);

  DailyTodo moveTo(String targetDate, {String? fromDate}) {
    DateTime utcDay(String date) => DateTime.parse('${date}T00:00:00Z');
    final delta = utcDay(targetDate).difference(utcDay(fromDate ?? date));
    return copyWith(date: dayString(utcDay(date).add(delta)),
      endDate: dayString(utcDay(endDate).add(delta)));
  }

  String get timeLabel => startTime != null && endTime != null
      ? '$startTime–$endTime' : '全天';

  factory DailyTodo.fromJson(dynamic value) {
    final j = mapOf(value);
    final rawColor = j['colorValue'];
    final decodedColor = rawColor is int ? rawColor : int.tryParse('$rawColor');
    String? parseTime(dynamic value) {
      final time = _optional(value);
      return time != null && time.length == 8 && time.endsWith(':00')
        ? time.substring(0, 5) : time;
    }
    final start = parseTime(j['startTime']);
    final end = parseTime(j['endTime']);
    return DailyTodo(
      id: textOf(j['id']), date: textOf(j['date'], textOf(j['startDate'])),
      endDate: _optional(j['endDate']),
      title: textOf(j['title']), note: textOf(j['note']),
      completed: j['completed'] == true,
      colorValue: DailyTodoColors.choices.contains(decodedColor)
          ? decodedColor! : DailyTodoColors.defaultColor,
      startTime: validTimeRange(start, end,
        acrossDays: textOf(j['endDate'], textOf(j['date'])) != textOf(j['date'])) ? start : null,
      endTime: validTimeRange(start, end,
        acrossDays: textOf(j['endDate'], textOf(j['date'])) != textOf(j['date'])) ? end : null,
      sortOrder: intOf(j['sortOrder']),
    );
  }

  static String? _optional(dynamic value) {
    final text = textOf(value).trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'title': title, 'note': note,
    'completed': completed, 'colorValue': colorValue,
    'endDate': endDate, 'startTime': startTime, 'endTime': endTime,
    'sortOrder': sortOrder,
  };

  DailyTodo copyWith({
    String? id, String? date, String? endDate, String? title, String? note, bool? completed,
    int? colorValue, String? startTime, String? endTime,
    int? sortOrder,
    bool clearTime = false,
  }) {
    // Moving a multi-day item moves its entire duration, not just its start.
    final nextDate = date ?? this.date;
    var nextEndDate = endDate ?? this.endDate;
    if (date != null && date != this.date && endDate == null &&
        validDate(date) && validDate(this.date) && validDate(this.endDate)) {
      DateTime utcDay(String v) => DateTime.parse('${v}T00:00:00Z');
      final delta = utcDay(date).difference(utcDay(this.date));
      nextEndDate = dayString(utcDay(this.endDate).add(delta));
    }
    return DailyTodo(
      id: id ?? this.id, date: nextDate, endDate: nextEndDate,
      title: title ?? this.title, note: note ?? this.note,
      completed: completed ?? this.completed,
      colorValue: colorValue ?? this.colorValue,
      startTime: clearTime ? null : (startTime ?? this.startTime),
      endTime: clearTime ? null : (endTime ?? this.endTime),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
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
      item.moveTo(targetDate)
    else
      item];
}

/// Reorders only items on the selected date; records on other dates are intact.
/// newIndex is already adjusted by ReorderableListView.onReorderItem.
List<DailyTodo> reorderDailyTodosForDay(
    List<DailyTodo> items, String date, int oldIndex, int newIndex) {
  final dayItems = items.where((item) => item.overlaps(from: date, to: date)).toList();
  if (oldIndex < 0 || oldIndex >= dayItems.length ||
      newIndex < 0 || newIndex >= dayItems.length) {
    return [...items];
  }
  final moved = dayItems.removeAt(oldIndex);
  dayItems.insert(newIndex, moved);
  var next = 0;
  return [for (final item in items)
    if (item.overlaps(from: date, to: date)) dayItems[next++] else item];
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
