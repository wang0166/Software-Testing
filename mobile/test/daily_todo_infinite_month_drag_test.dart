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
}
