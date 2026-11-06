import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/shell_page.dart';
import 'package:mobile/screens/view_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('下属动态角标在默认日历上可见，数字精确且零问题隐藏', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('leader', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(
      app: app, subordinateIssueCount: 3,
    )));
    await tester.pump();
    expect(find.widgetWithText(ChoiceChip, '日历视图'), findsOneWidget);
    expect(find.byKey(const Key('team_tab_issue_badge')), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('team_tab_issue_badge')),
      matching: find.text('3'),
    ), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: ViewPage(
      app: app, subordinateIssueCount: 0,
    )));
    await tester.pump();
    expect(find.byKey(const Key('team_tab_issue_badge')), findsNothing);
  });

  testWidgets('员工不能看到下属异常角标', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(
      app: app, subordinateIssueCount: 3,
    )));
    await tester.pump();
    expect(find.byKey(const Key('team_tab_issue_badge')), findsNothing);
  });

  testWidgets('底部导航不带角标，公司的下属动态标签显示已上报问题', (tester) async {
    final app = AppState();
    final totalIssues = await tester.runAsync(() async {
      await app.login('demo001', 'demo123456');
      final task = (await app.repo.tasks(personal: false))
          .firstWhere((item) => item.id == 310);
      await app.repo.updateTaskProgress(task,
        status: 'BLOCKED', percent: 65, note: '数据库接口受阻');
      await app.login('leader', 'demo123456');
      final rows = await app.repo.subordinatesTaskOverview();
      return rows.fold<int>(0, (sum, row) => sum + row.visibleIssueCount);
    });
    // Verify the demo has a *real* unresolved issue, not a fabricated UI count.
    expect(totalIssues, greaterThan(0));
    await tester.pumpWidget(MaterialApp(home: ShellPage(app: app)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('main_view_issue_badge')), findsNothing);
    expect(find.byKey(const Key('main_view_task_badge')), findsNothing);
    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('team_tab_issue_badge')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

}
