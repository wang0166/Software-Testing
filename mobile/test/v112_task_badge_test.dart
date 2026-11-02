import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/core/task_read_tracker.dart';
import 'package:mobile/screens/view_page.dart';
import 'package:mobile/screens/shell_page.dart';

const received = <TaskItem>[
  TaskItem(id: 310, name: '接口联调', details: '', status: 'IN_PROGRESS', source: 'RECEIVED'),
  TaskItem(id: 311, name: '迭代周报', details: '', status: 'NOT_STARTED', source: 'RECEIVED'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('新接收任务默认未查看，只有打开详情才清除，并跨重启保留', () async {
    final tracker = TaskReadTracker(12);
    expect(await tracker.unreadIds(received), {310, 311});
    await tracker.markViewed(310);
    expect(await tracker.unreadIds(received), {311});
    final restarted = TaskReadTracker(12);
    expect(await restarted.unreadIds(received), {311});
    // 新派发的 assignmentId 出现时自动成为未读。
    expect(await restarted.unreadIds([...received,
      const TaskItem(id: 312, name: '新收到的任务', details: '',
        status: 'NOT_STARTED', source: 'RECEIVED'),
    ]), {311, 312});
  });

  test('个人任务不计入未读；已读记录按员工账号隔离', () async {
    final tracker = TaskReadTracker(12);
    await tracker.markViewed(310);
    final manager = TaskReadTracker(9);
    expect(await manager.unreadIds(received), {310, 311});
    expect(await tracker.unreadIds([...received,
      const TaskItem(id: 999, name: '个人自建', details: '',
        status: 'NOT_STARTED', source: 'PERSONAL'),
    ]), {311});
  });

  testWidgets('任务蓝色角标和下属红色角标独立，零未读隐藏', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('leader', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app,
      subordinateIssueCount: 2, unreadTaskIds: const {310, 311})));
    await tester.pump();
    expect(find.byKey(const Key('task_tab_unread_badge')), findsOneWidget);
    expect(find.byKey(const Key('team_tab_issue_badge')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('task_tab_unread_badge')),
      matching: find.text('2')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app,
      subordinateIssueCount: 2, unreadTaskIds: const {})));
    await tester.pump();
    expect(find.byKey(const Key('task_tab_unread_badge')), findsNothing);
    expect(find.byKey(const Key('team_tab_issue_badge')), findsOneWidget);
  });

  testWidgets('仅打开任务列表不清除未读；进入任务详情才通知已查看', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final viewed = <int>[];
    await tester.pumpWidget(MaterialApp(home: ViewPage(
      app: app, unreadTaskIds: const {310, 311},
      onTaskViewed: viewed.add,
    )));
    await tester.pump();
    await tester.tap(find.text('任务清单').first);
    await tester.pump();
    expect(viewed, isEmpty);
    expect(find.byKey(const Key('task_tab_unread_badge')), findsOneWidget);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(find.text('完成模块联调'), findsWidgets);
    await tester.tap(find.text('完成模块联调').first);
    await tester.pump();
    expect(viewed, contains(310));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('底部视图按钮无任何数字角标，角标只在子选项中', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('leader', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ShellPage(app: app)));
    // HomePage loads mock logs asynchronously (220ms fake timer).
    // Flush requests while the widget is mounted, then dispose cleanly.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('main_view_issue_badge')), findsNothing);
    expect(find.byKey(const Key('main_view_task_badge')), findsNothing);
    final nav = find.byKey(const Key('nav_1'));
    expect(nav, findsOneWidget);
    await tester.tap(nav);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('下属动态'), findsOneWidget);
    expect(find.text('任务清单'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
