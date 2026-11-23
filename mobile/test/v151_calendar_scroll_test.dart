import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/core/gantt_utils.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskItem task(int id, String date) => TaskItem(
  id: id, name: '测试任务$id', details: '任务日历', status: 'IN_PROGRESS',
  source: 'RECEIVED', startDate: date, deadline: date,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('甘特图仍保留全部重叠任务的数据', () {
    final date = DateTime(2026, 11, 7);
    final spans = buildGanttSpans(
      [for (var i = 1; i <= 5; i++) task(i, dayString(date))], date, date);
    expect(spans, hasLength(5));
    expect(allocateGanttLanes(spans), hasLength(5));
  });

  testWidgets('月视图直接显示任务文字和 +N，不再显示小圆点或内部任务滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final selected = chinaNow.add(const Duration(days: 1));
    final key = Key('calendar_more_${dayString(selected)}');
    await tester.pumpWidget(MaterialApp(home: CalendarPage(
      app: app, initialMode: 0, initialDate: selected)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_task_scroll')), findsNothing);
    expect(find.byKey(const Key('calendar_week_task_scroll')), findsNothing);
    expect(find.byKey(key), findsOneWidget);
    // Two task titles + the overflow marker must fit without RenderFlex errors.
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage, skipOffstage: false), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('日视图展示全部任务但不创建内部小列表', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: CalendarPage(
      app: app, initialMode: 2, initialDate: chinaNow.add(const Duration(days: 1)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_task_scroll')), findsNothing);
    expect(find.textContaining('任务安排'), findsWidgets);
  });

  testWidgets('窄屏月历在任务较多时不会产生 RenderFlex 溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final selected = chinaNow.add(const Duration(days: 1));
    final moreKey = Key('calendar_more_${dayString(selected)}');
    await tester.pumpWidget(MaterialApp(
      home: CalendarPage(app: app, initialMode: 0, initialDate: selected),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(moreKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(moreKey), findsOneWidget);
  });
}
