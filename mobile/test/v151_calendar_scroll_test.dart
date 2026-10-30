import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/core/gantt_utils.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskItem _task(int id, String date) => TaskItem(
  id: id,
  name: '测试任务$id',
  details: '用于验证同一天超过三个任务时不会丢失',
  status: 'IN_PROGRESS',
  source: 'RECEIVED',
  startDate: date,
  deadline: date,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('月周视图为重叠任务分配全部轨道，第四条及之后不会被丢弃', () {
    final day = DateTime(2026, 10, 30);
    final date = dayString(day);
    final spans = buildGanttSpans(
      [for (var i = 1; i <= 5; i++) _task(i, date)], day, day);
    final rows = allocateGanttLanes(spans);
    expect(rows, hasLength(5));
    expect(rows.map((row) => row.lane).toList(), [0, 1, 2, 3, 4]);
    expect(rows.where((row) => row.lane >= 3).length, 2);
  });

  test('无日期冲突的任务复用已有轨道，不会无意义增加日历高度', () {
    final spans = buildGanttSpans([
      _task(1, '2026-10-26'),
      _task(2, '2026-10-27'),
      _task(3, '2026-10-28'),
    ], DateTime(2026, 10, 26), DateTime(2026, 11, 1));
    expect(allocateGanttLanes(spans).map((row) => row.lane), [0, 0, 0]);
  });

  testWidgets('日视图超三项时任务区内部可滚动，同时保留甘特图文字跳转', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final selected = chinaNow.add(const Duration(days: 1));
    await tester.pumpWidget(MaterialApp(home: CalendarPage(
      app: app, initialMode: 2, initialDate: selected,
    )));
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('calendar_day_task_scroll'));
    expect(list, findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(list, const Offset(0, -110));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(0));
    expect(find.byKey(const Key('calendar_more_tasks')), findsOneWidget);
    expect(find.textContaining('日志'), findsNothing);
  });

  testWidgets('周视图重叠任务超过三轨时可以在横条区上下滑动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final selected = chinaNow.add(const Duration(days: 1));
    await tester.pumpWidget(MaterialApp(home: CalendarPage(
      app: app, initialMode: 1, initialDate: selected,
    )));
    await tester.pumpAndSettle();

    final weekStart = selected.subtract(Duration(days: selected.weekday - 1));
    final week = find.byKey(ValueKey('calendar_week_task_scroll_${dayString(weekStart)}'));
    expect(week, findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: week, matching: find.byType(Scrollable)),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(find.byKey(const Key('calendar_more_tasks')), findsOneWidget);
  });
}
