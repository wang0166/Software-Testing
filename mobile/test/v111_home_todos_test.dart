import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/daily_todos.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/screens/home_page.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('每日事项按账号隔离，增删改及完成状态在重启后保留', () async {
    const first = DailyTodoStorage(12);
    const second = DailyTodoStorage(13);
    final date = DateTime(2026, 11, 4);
    final original = DailyTodo(id: 'todo-001', date: '${date.year}-11-04',
      title: '个人阅读计划');
    await first.write([original]);
    expect((await first.read()).single.title, '个人阅读计划');
    expect(await second.read(), isEmpty);
    await first.write([original.copyWith(title: '修改个人计划', completed: true)]);
    expect((await first.read()).single.completed, isTrue);
    expect((await first.read()).single.title, '修改个人计划');
    await first.write([]);
    expect(await first.read(), isEmpty);
  });

  test('事项不进入公司任务/日志存储', () async {
    final repo = MockRepository();
    await repo.login('demo001', 'demo123456');
    final tasksBefore = await repo.tasks(personal: false);
    final logsBefore = await repo.logs();
    await const DailyTodoStorage(12).write([
      const DailyTodo(id: 'todo-002', date: '2026-11-04', title: '复习基础知识'),
    ]);
    expect((await repo.tasks(personal: false)).length, tasksBefore.length);
    expect((await repo.logs()).length, logsBefore.length);
  });

  testWidgets('首页三块信息布局；任务看板展示当前执行人收到的任务', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomePage(
      app: app, onTab: (_) {},
    ))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('事件纪'), findsOneWidget);
    expect(find.text('任务看板'), findsOneWidget);
    expect(find.text('每日事项'), findsOneWidget);
    expect(find.text('个人10大信息'), findsNothing);
    expect(find.text('日志展示'), findsNothing);
    expect(find.text('完成模块联调'), findsOneWidget);
    expect(find.byType(DailyTodosCalendar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('个人事项月历可打开新增事项输入框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SafeArea(child: DailyTodosCalendar(userId: 12)),
    )));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_todo_month_grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily_todo_add_header')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_todo_title_input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('daily_todo_title_input')), '阅读半小时');
    await tester.tap(find.byKey(const Key('daily_todo_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('阅读半小时'), findsOneWidget);
  });
}
