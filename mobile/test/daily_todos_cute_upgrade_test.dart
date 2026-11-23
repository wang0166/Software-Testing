import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/daily_todos.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('旧版个人事项读取后自动获得默认颜色，完成状态和账号隔离不变', () async {
    SharedPreferences.setMockInitialValues({
      'pandora_daily_todos_v1_44': jsonEncode([
        {'id': 'legacy', 'date': '2026-11-13', 'title': '旧待办',
          'note': '不要丢失', 'completed': true},
      ]),
    });
    final oldItem = (await const DailyTodoStorage(44).read()).single;
    expect(oldItem.colorValue, DailyTodoColors.defaultColor);
    expect(oldItem.startTime, isNull);
    expect(oldItem.endTime, isNull);
    expect(oldItem.timeLabel, '全天');
    expect(oldItem.completed, isTrue);
    expect(oldItem.note, '不要丢失');
    expect(await const DailyTodoStorage(45).read(), isEmpty);
  });

  test('开始结束时间和颜色持久化，拒绝无效时段', () async {
    expect(DailyTodo.validTimeRange(null, null), isTrue);
    expect(DailyTodo.validTimeRange('09:00', null), isFalse);
    expect(DailyTodo.validTimeRange(null, '10:00'), isFalse);
    expect(DailyTodo.validTimeRange('10:00', '09:00'), isFalse);
    expect(DailyTodo.validTimeRange('09:00', '09:00'), isFalse);
    expect(DailyTodo.validTimeRange('23:00', '24:00'), isFalse);
    expect(DailyTodo.validTimeRange('09:00', '10:30'), isTrue);
    const item = DailyTodo(
      id: 'timed', date: '2026-11-13', title: '读书',
      colorValue: DailyTodoColors.mint,
      startTime: '09:00', endTime: '10:30',
    );
    await const DailyTodoStorage(44).write([item]);
    final restored = (await const DailyTodoStorage(44).read()).single;
    expect(restored.colorValue, DailyTodoColors.mint);
    expect(restored.timeLabel, '09:00–10:30');
    expect(restored.copyWith(completed: true).colorValue, DailyTodoColors.mint);
    expect(restored.copyWith(clearTime: true).timeLabel, '全天');
  });

  test('拖动排序仅修改当天顺序，其他日期事项原位保留', () {
    const items = [
      DailyTodo(id: 'a', date: '2026-11-13', title: 'A'),
      DailyTodo(id: 'x', date: '2026-11-14', title: 'X'),
      DailyTodo(id: 'b', date: '2026-11-13', title: 'B'),
      DailyTodo(id: 'c', date: '2026-11-13', title: 'C'),
    ];
    final reordered = reorderDailyTodosForDay(items, '2026-11-13', 0, 2);
    expect(reordered.map((e) => e.id), ['b', 'x', 'c', 'a']);
    expect(reordered[1].date, '2026-11-14');
    expect(reordered[3].copyWith(date: '2026-11-15').date, '2026-11-15');
    // onReorderItem also passes pre-adjusted indices for upward movement.
    final upward = reorderDailyTodosForDay(items, '2026-11-13', 2, 0);
    expect(upward.map((e) => e.id), ['c', 'x', 'a', 'b']);
    final unchanged = reorderDailyTodosForDay(items, '2026-11-13', 1, 1);
    expect(unchanged.map((e) => e.id), ['a', 'x', 'b', 'c']);
  });

  testWidgets('彩色事项、颜色选择和日期拖放更新本地记录', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = chinaNow;
    final todayString = dayString(today);
    final target = today.day < DateUtils.getDaysInMonth(today.year, today.month)
        ? DateTime(today.year, today.month, today.day + 1)
        : DateTime(today.year, today.month, today.day - 1);
    final targetString = dayString(target);
    await const DailyTodoStorage(88).write([
      DailyTodo(id: 'drag-me', date: todayString, title: '今天的小计划'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 675, child: DailyTodosCalendar(userId: 88)),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_todo_drag_day_drag-me')), findsOneWidget);
    expect(find.byKey(Key('daily_todo_drop_$targetString')), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_todo_edit_drag-me')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_todo_start_time')), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_end_time')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily_todo_color_${DailyTodoColors.sky}')));
    await tester.tap(find.byKey(const Key('daily_todo_save_button')));
    await tester.pumpAndSettle();
    expect((await const DailyTodoStorage(88).read()).single.colorValue,
        DailyTodoColors.sky);

    final drop = tester.widget<DragTarget<String>>(
        find.byKey(Key('daily_todo_drop_$targetString')));
    drop.onAcceptWithDetails!(DragTargetDetails<String>(
      data: 'drag-me', offset: Offset.zero,
    ));
    await tester.pumpAndSettle();
    expect((await const DailyTodoStorage(88).read()).single.date,
      targetString);
    expect(tester.takeException(), isNull);
  });
}
