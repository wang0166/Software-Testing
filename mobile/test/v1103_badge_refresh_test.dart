import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/screens/view_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('演示账号初次及已有本地数据均获得真实可解决的问题任务', () async {
    final repo = MockRepository();
    await repo.login('demo002', 'demo123456');
    // Simulate an old installation that saved a list before V1.10.3.
    final previous = (await repo.tasks(personal: false))
        .where((t) => t.id != 399).toList();
    final p = await SharedPreferences.getInstance();
    await p.setString('pandora_mock_tasks_13',
      '[${previous.map((e) => jsonEncode(e.toJson())).join(',')}]');

    await repo.login('leader', 'demo123456');
    var rows = await repo.subordinatesTaskOverview();
    var member = rows.firstWhere((r) => r.userId == 13);
    expect(member.visibleIssueCount, 1);
    expect(member.tasks.where((t) => t.id == 399).length, 1);
    final history = await repo.subordinateTaskProgressHistory(13, 399);
    expect(history, hasLength(1));
    expect(history.first.note, contains('演示异常'));

    // Repeated fetches do not duplicate demo incidents.
    rows = await repo.subordinatesTaskOverview();
    expect(rows.firstWhere((r) => r.userId == 13).visibleIssueCount, 1);

    await repo.login('demo002', 'demo123456');
    final task = (await repo.tasks(personal: false)).firstWhere((t) => t.id == 399);
    await repo.updateTaskProgress(task,
      status: 'IN_PROGRESS', percent: 60, note: '权限问题已解决');
    await repo.login('leader', 'demo123456');
    rows = await repo.subordinatesTaskOverview();
    expect(rows.firstWhere((r) => r.userId == 13).visibleIssueCount, 0);
  });

  test('创始人能统计跨部门问题，普通员工没有管理范围', () async {
    final repo = MockRepository();
    await repo.login('founder', 'demo123456');
    final founder = await repo.subordinatesTaskOverview();
    expect(founder.fold<int>(0, (sum, row) => sum + row.visibleIssueCount), 2);
    await repo.login('manager', 'demo123456');
    final manager = await repo.subordinatesTaskOverview();
    expect(manager.fold<int>(0, (sum, row) => sum + row.visibleIssueCount), 1);
    await repo.login('productmanager', 'demo123456');
    final product = await repo.subordinatesTaskOverview();
    expect(product.fold<int>(0, (sum, row) => sum + row.visibleIssueCount), 1);
    await repo.login('demo001', 'demo123456');
    expect(await repo.subordinatesTaskOverview(), isEmpty);
  });


  test('员工提交受阻反馈后，团队长与创始人均可查到该问题', () async {
    final repo = MockRepository();
    await repo.login('demo001', 'demo123456');
    final task = (await repo.tasks(personal: false)).firstWhere((t) => t.id == 310);
    await repo.updateTaskProgress(task,
      status: 'BLOCKED', percent: 65, note: '接口返回 403，请上级协助');
    await repo.login('leader', 'demo123456');
    final leader = await repo.subordinatesTaskOverview();
    expect(leader.firstWhere((row) => row.userId == 12).visibleIssueCount, 1);
    await repo.login('founder', 'demo123456');
    final founder = await repo.subordinatesTaskOverview();
    expect(founder.firstWhere((row) => row.userId == 12).visibleIssueCount, 1);
  });

  testWidgets('错误无法计算时显示警告，不伪装成未解决问题', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(
      app: app, issueCountUnavailable: true,
    )));
    await tester.pump();
    expect(find.byKey(const Key('team_tab_issue_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('team_tab_issue_badge')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
