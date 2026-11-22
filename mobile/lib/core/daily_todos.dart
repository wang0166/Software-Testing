import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// A personal, date-specific item. It is intentionally unrelated to company
/// task assignments, task approvals and work logs.
class DailyTodo {
  final String id;
  final String date;
  final String? _endDate;
  final String? startTime, endTime;
  final String title;
  final String note;
  final bool completed;

  const DailyTodo({required this.id, required this.date, required this.title,
    String? endDate, this.startTime, this.endTime,
    this.note = '', this.completed = false}) : _endDate = endDate;

  String get endDate => _endDate ?? date;

  bool overlaps({String? from, String? to}) =>
    (from == null || endDate.compareTo(from) >= 0) &&
    (to == null || date.compareTo(to) <= 0);

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

  static bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return _datePattern.hasMatch(value) && parsed != null &&
      parsed.year > 0 && dayString(parsed) == value;
  }

  static bool validTimeRange(String? start, String? end, {bool acrossDays = false}) {
    if (start == null || end == null) return start == null && end == null;
    return _timePattern.hasMatch(start) && _timePattern.hasMatch(end) &&
      (acrossDays || end.compareTo(start) > 0);
  }

  bool get hasValidRange => validDate(date) && validDate(endDate) &&
    endDate.compareTo(date) >= 0 &&
    validTimeRange(startTime, endTime, acrossDays: date != endDate);

  DailyTodo moveTo(String newDate, {String? fromDate}) {
    DateTime utcDay(String value) => DateTime.parse('${value}T00:00:00Z');
    final shift = utcDay(newDate).difference(utcDay(fromDate ?? date));
    final newStart = utcDay(date).add(shift);
    final newEnd = utcDay(endDate).add(shift);
    return DailyTodo(id: id, date: dayString(newStart), endDate: dayString(newEnd),
      title: title, note: note, completed: completed,
      startTime: startTime, endTime: endTime);
  }

  factory DailyTodo.fromJson(dynamic value) {
    final j = mapOf(value);
    return DailyTodo(
      id: textOf(j['id']), date: textOf(j['date'], textOf(j['startDate'])),
      endDate: _optional(j['endDate']),
      startTime: _timeFromJson(j['startTime']),
      endTime: _timeFromJson(j['endTime']),
      title: textOf(j['title']), note: textOf(j['note']),
      completed: j['completed'] == true,
    );
  }

  static String? _optional(dynamic value) {
    final text = textOf(value).trim();
    return text.isEmpty ? null : text;
  }

  static String? _timeFromJson(dynamic value) {
    final time = _optional(value);
    return time != null && time.length == 8 && time.endsWith(':00')
      ? time.substring(0, 5) : time;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'title': title, 'note': note,
    'completed': completed, 'endDate': endDate,
    'startTime': startTime, 'endTime': endTime,
  };

  DailyTodo copyWith({String? id, String? date, String? title, String? note,
    bool? completed}) {
    final moved = date == null || date == this.date ? this : moveTo(date);
    return DailyTodo(id: id ?? this.id, date: moved.date, endDate: moved.endDate,
      title: title ?? this.title, note: note ?? this.note,
      completed: completed ?? this.completed, startTime: startTime, endTime: endTime);
  }
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
