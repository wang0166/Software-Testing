import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/daily_todos.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

String monthTitle(DateTime month) => '${month.year}年${month.month}月';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('长按事项贴住右边缘连续翻过三个月，放下后保存目标日期', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateUtils.dateOnly(chinaNow);
    final from = dayString(now);
    await const DailyTodoStorage(133).write([
      DailyTodo(id: 'travel-three-months', date: from, title: '跨月搬家事项'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 830, child: DailyTodosCalendar(userId: 133)),
    )));
    await tester.pumpAndSettle();

    // Start from the item chip INSIDE the calendar (not the stable day list):
    // this catches regressions where paging disposes the dragged widget.
    final dragSource = find.byKey(
        const Key('daily_todo_drag_calendar_travel-three-months'));
    expect(dragSource, findsOneWidget);
    final gridRect = tester.getRect(find.byKey(const Key('daily_todo_month_swipe')));
    final gesture = await tester.startGesture(tester.getCenter(dragSource));
    await tester.pump(const Duration(milliseconds: 700)); // Start long press.
    await gesture.moveTo(Offset(gridRect.right - 5, gridRect.center.dy));
    await tester.pump(const Duration(milliseconds: 100));

    // The finger remains stationary. The month must keep advancing, with no
    // need to release the todo or move onto a tiny header arrow.
    for (var step = 1; step <= 3; step++) {
      await tester.pump(const Duration(milliseconds: 660));
      final expected = DateTime(now.year, now.month + step, 1);
      expect(find.text(monthTitle(expected)), findsOneWidget);
      expect(find.byKey(
          const Key('daily_todo_drag_calendar_travel-three-months'),
          skipOffstage: false), findsWidgets);
    }

    final destination = DateTime(now.year, now.month + 3, 15);
    final destinationDate = dayString(destination);
    await gesture.moveTo(tester.getCenter(
        find.byKey(Key('daily_todo_cell_$destinationDate'))));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final stored = await const DailyTodoStorage(133).read();
    expect(stored.single.date, destinationDate);
    expect(stored.single.title, '跨月搬家事项');
    expect(tester.takeException(), isNull);
  });

  testWidgets('不拖事项时，左右横滑日历也能切换月份', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateUtils.dateOnly(chinaNow);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 780, child: DailyTodosCalendar(userId: 134)),
    )));
    await tester.pumpAndSettle();
    final swipe = find.byKey(const Key('daily_todo_month_swipe'));
    await tester.fling(swipe, const Offset(-190, 0), 650);
    await tester.pumpAndSettle();
    expect(find.text(monthTitle(DateTime(now.year, now.month + 1))), findsOneWidget);
    await tester.fling(swipe, const Offset(190, 0), 650);
    await tester.pumpAndSettle();
    expect(find.text(monthTitle(DateTime(now.year, now.month))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一次拖动可以向右、向左反向翻月，移回中间停止', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateUtils.dateOnly(chinaNow);
    const storage = DailyTodoStorage(135);
    final originalDate = dayString(now);
    await storage.write([
      DailyTodo(id: 'reverse', date: originalDate, title: '双向拖动事项'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 830, child: DailyTodosCalendar(userId: 135)),
    )));
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const Key('daily_todo_month_swipe')));
    final source = find.byKey(const Key('daily_todo_drag_calendar_reverse'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(Offset(grid.right - 5, grid.center.dy));
    await tester.pump(const Duration(milliseconds: 660));
    expect(find.text(monthTitle(DateTime(now.year, now.month + 1))), findsOneWidget);

    // Reverse directly, without lifting the finger or returning to the source.
    await gesture.moveTo(Offset(grid.left + 5, grid.center.dy));
    await tester.pump(const Duration(milliseconds: 660));
    expect(find.text(monthTitle(now)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 660));
    final previous = DateTime(now.year, now.month - 1, 1);
    expect(find.text(monthTitle(previous)), findsOneWidget);

    await gesture.moveTo(grid.center);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(monthTitle(previous)), findsOneWidget);
    final destination = dayString(DateTime(previous.year, previous.month, 15));
    await gesture.moveTo(tester.getCenter(
        find.byKey(Key('daily_todo_cell_$destination'))));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(monthTitle(previous)), findsOneWidget);
    expect((await storage.read()).single.date, destination);
    expect(tester.takeException(), isNull);
  });

  for (final direction in [-1, 1]) {
    testWidgets('松开${direction < 0 ? '左' : '右'}侧翻月箭头后停止且不误移动事项', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateUtils.dateOnly(chinaNow);
      const storage = DailyTodoStorage(136);
      final originalDate = dayString(now);
      await storage.write([
        DailyTodo(id: 'release', date: originalDate, title: '松手停止事项'),
      ]);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(
        body: SizedBox(height: 830, child: DailyTodosCalendar(userId: 136)),
      )));
      await tester.pumpAndSettle();
      // Start in the day list, exercising the other LongPressDraggable.
      final source = find.byKey(const Key('daily_todo_drag_day_release'));
      final arrow = find.byKey(Key(direction < 0
          ? 'daily_todo_drag_prev_month' : 'daily_todo_drag_next_month'));
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(tester.getCenter(arrow));
      await tester.pump(const Duration(milliseconds: 660));
      final visible = DateTime(now.year, now.month + direction);
      expect(find.text(monthTitle(visible)), findsOneWidget);
      await gesture.up(); // No move back to the middle before releasing.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text(monthTitle(visible)), findsOneWidget);
      expect((await storage.read()).single.date, originalDate);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('指针取消后停止翻月，旧定时器不会继续运行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateUtils.dateOnly(chinaNow);
    const storage = DailyTodoStorage(137);
    final originalDate = dayString(now);
    await storage.write([
      DailyTodo(id: 'cancel', date: originalDate, title: '取消拖动事项'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 830, child: DailyTodosCalendar(userId: 137)),
    )));
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const Key('daily_todo_month_swipe')));
    final source = find.byKey(const Key('daily_todo_drag_calendar_cancel'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(Offset(grid.right - 5, grid.center.dy));
    await tester.pump(const Duration(milliseconds: 660));
    final visible = DateTime(now.year, now.month + 1);
    expect(find.text(monthTitle(visible)), findsOneWidget);
    await gesture.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text(monthTitle(visible)), findsOneWidget);
    expect((await storage.read()).single.date, originalDate);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手指停在日历右边缘直接松开，之后月份保持不变', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateUtils.dateOnly(chinaNow);
    const storage = DailyTodoStorage(138);
    final originalDate = dayString(now);
    await storage.write([
      DailyTodo(id: 'grid-release', date: originalDate, title: '边缘松手事项'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 830, child: DailyTodosCalendar(userId: 138)),
    )));
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const Key('daily_todo_month_swipe')));
    final source = find.byKey(const Key('daily_todo_drag_calendar_grid-release'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(Offset(grid.right - 5, grid.center.dy));
    await tester.pump(const Duration(milliseconds: 660));
    final visible = DateTime(now.year, now.month + 1);
    expect(find.text(monthTitle(visible)), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text(monthTitle(visible)), findsOneWidget);
    // A valid visible date may accept the drop, but a stale hidden date must not.
    final stored = (await storage.read()).single;
    if (stored.date != originalDate) {
      final date = DateTime.parse(stored.date);
      expect(date.year, visible.year);
      expect(date.month, visible.month);
    }
    expect(tester.takeException(), isNull);
  });
}
