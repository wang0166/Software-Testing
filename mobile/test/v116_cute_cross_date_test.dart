import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/daily_todos.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/core/theme.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';
import 'package:mobile/widgets/business.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('跨日期移动仅改变日期，颜色、起止时间、状态和其他事项不变', () {
    const todo = DailyTodo(
      id: 'move', date: '2026-11-30', title: '小熊读书计划',
      colorValue: DailyTodoColors.lilac,
      startTime: '09:00', endTime: '10:30', completed: true,
    );
    const other = DailyTodo(id: 'stay', date: '2026-11-30', title: '保留原位');
    final result = moveDailyTodoToDate([todo, other], 'move', '2026-12-01');
    expect(result[0].date, '2026-12-01');
    expect(result[0].id, todo.id);
    expect(result[0].colorValue, todo.colorValue);
    expect(result[0].startTime, '09:00');
    expect(result[0].endTime, '10:30');
    expect(result[0].completed, isTrue);
    expect(result[1].date, '2026-11-30');
    expect(moveDailyTodoToDate(result, 'missing', '2027-01-01'), result);
    expect(moveDailyTodoToDate(result, 'move', 'invalid'), result);
  });

  testWidgets('跨月日期格支持拖放，移动后自动显示新月份并持久化', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateUtils.dateOnly(chinaNow);
    final from = dayString(today);
    final nextMonth = DateTime(today.year, today.month + 1, 1);
    final target = dayString(nextMonth);
    await const DailyTodoStorage(116).write([
      DailyTodo(id: 'cross', date: from, title: '跨月的可爱计划'),
    ]);
    await tester.pumpWidget(MaterialApp(theme: pandoraTheme(), home:
      const Scaffold(body: SizedBox(height: 675,
        child: DailyTodosCalendar(userId: 116)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_todo_drag_day_cross')), findsOneWidget);
    expect(find.byKey(Key('daily_todo_drop_$target')), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_drag_next_month')), findsOneWidget);

    final drop = tester.widget<DragTarget<String>>(
      find.byKey(Key('daily_todo_drop_$target')));
    drop.onAcceptWithDetails!(DragTargetDetails<String>(
      data: 'cross', offset: Offset.zero));
    await tester.pumpAndSettle();

    final items = await const DailyTodoStorage(116).read();
    expect(items.single.date, target);
    expect(find.text('${nextMonth.year}年${nextMonth.month}月'), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_drag_day_cross')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑日历多事项的 +N 标记不会发生像素级底部溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = dayString(chinaNow);
    await const DailyTodoStorage(119).write([
      DailyTodo(id: 'overflow-a', date: today, title: '事项甲'),
      DailyTodo(id: 'overflow-b', date: today, title: '事项乙'),
      DailyTodo(id: 'overflow-c', date: today, title: '事项丙'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 675, child: DailyTodosCalendar(userId: 119)),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('daily_todo_cell_$today')), findsOneWidget);
    // 即使高度较小也要保留可长按的事项，不再只剩 +N。
    expect(find.byKey(const Key('daily_todo_drag_calendar_overflow-a')),
        findsOneWidget);
    // The original v2.0.2 calendar produced a RenderFlex overflow of 0.13px.
    expect(tester.takeException(), isNull);
    final more = find.byKey(Key('daily_todo_more_$today'));
    if (more.evaluate().isNotEmpty) {
      expect(tester.getSize(more).height, 12.0);
    }
  });

  testWidgets('中等高度月历至少显示两条可长按事项并保留超出数量', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = dayString(chinaNow);
    await const DailyTodoStorage(120).write([
      DailyTodo(id: 'visible-a', date: today, title: '阅读计划'),
      DailyTodo(id: 'visible-b', date: today, title: '运动计划'),
      DailyTodo(id: 'hidden-c', date: today, title: '整理书包'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 810, child: DailyTodosCalendar(userId: 120)),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_todo_drag_calendar_visible-a')),
        findsOneWidget);
    expect(find.byKey(const Key('daily_todo_drag_calendar_visible-b')),
        findsOneWidget);
    expect(find.byKey(const Key('daily_todo_drag_calendar_hidden-c')),
        findsNothing);
    expect(find.byKey(Key('daily_todo_more_$today')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    final firstDrag = tester.widget<LongPressDraggable<String>>(
      find.byKey(const Key('daily_todo_drag_calendar_visible-a')));
    expect(firstDrag.data, 'visible-a');
    expect(find.byKey(const Key('daily_todo_day_list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('每日事项日历复用工作视图的周分隔样式，不使用独立日期方框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateUtils.dateOnly(chinaNow);
    final date = dayString(today);
    await const DailyTodoStorage(117).write([
      DailyTodo(id: 'style', date: date, title: '可拖动的小计划'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 990, child: DailyTodosCalendar(userId: 117)),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_todo_month_grid')), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_week_0')), findsOneWidget);
    final week = tester.widget<Container>(
      find.byKey(const Key('daily_todo_week_0')));
    final weekDecoration = week.decoration! as BoxDecoration;
    expect(weekDecoration.border, isNotNull);
    final dateCell = tester.widget<Container>(
      find.byKey(Key('daily_todo_cell_$date')));
    final cellDecoration = dateCell.decoration! as BoxDecoration;
    expect(cellDecoration.border, isNull);
    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const Key('daily_todo_drag_day_style')), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_drag_calendar_style')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('各业务页面共用粉紫软萌组件风格', (tester) async {
    final theme = pandoraTheme();
    expect(theme.colorScheme.primary, Palette.primary);
    expect(theme.scaffoldBackgroundColor, Palette.paper);
    await tester.pumpWidget(MaterialApp(theme: theme,
      home: const Scaffold(body: Center(
        child: BusinessPanel(title: '任务信息',
          child: Text('已完成'))))));
    expect(find.text('任务信息'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
