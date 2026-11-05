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

  testWidgets('底部导航没有红点，下属动态子页仍可显示异常角标', (tester) async {
    final app = AppState();
    await tester.runAsync(() async {
      await app.login('demo001', 'demo123456');
      final task = (await app.repo.tasks(personal: false))
        .firstWhere((item) => item.id == 310);
      await app.repo.updateTaskProgress(task,
        status: 'BLOCKED', percent: 65, note: '数据库接口受阻');
      await app.login('leader', 'demo123456');
    });
    await tester.pumpWidget(MaterialApp(home: ShellPage(app: app)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('main_view_issue_badge')), findsNothing);
    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pump();
    expect(find.byKey(const Key('team_tab_issue_badge')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
