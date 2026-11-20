import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/tasks_page.dart';
import 'package:mobile/screens/home_page.dart';
import 'package:mobile/screens/task_map_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('任务台账保留负责人、进度备注及类型标签字段', () {
    final task = TaskItem.fromJson({
      'id': 12, 'name': '测试任务', 'assigneeName': '张三',
      'progressRemark': '联调进行中', 'type': 'TESTING',
    });
    expect(task.assigneeName, '张三');
    expect(task.progressNote, '联调进行中');
    expect(taskTypeLabel(task.taskType), '测试');
  });

  test('员工 MBTI 为选填、未提供时保留空值', () {
    final user = UserProfile.fromJson({
      'id': 2, 'username': 'someone', 'realName': '员工甲',
      'role': 'EMPLOYEE', 'mbtiType': 'ISTJ',
    });
    expect(user.mbtiType, 'ISTJ');
    expect(UserProfile.fromJson({'id': 3}).mbtiType, '');
  });

  testWidgets('任务台账有横向与纵向滚动结构', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TasksPage(app: app))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task_ledger_horizontal')), findsOneWidget);
    expect(find.byKey(const Key('task_ledger_vertical')), findsOneWidget);
    expect(find.text('任务执行台账'), findsOneWidget);
  });

  testWidgets('甲方新版首页仅有事件纪、任务看板和每日事项', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      HomePage(app: app, onTab: (_) {}))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event_history_panel')), findsOneWidget);
    expect(find.byKey(const Key('task_board_panel')), findsOneWidget);
    expect(find.byKey(const Key('daily_todo_panel')), findsOneWidget);
    // The removed personal-info/log sections must NOT reappear.
    expect(find.byKey(const Key('home_edit_03')), findsNothing);
    expect(find.byKey(const Key('home_edit_04')), findsNothing);
    expect(find.text('个人10大信息'), findsNothing);
    expect(find.text('日志展示'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 地图在演示模式下明确提示未连接 DeepSeek 服务', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      TaskMapPage(app: app))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_map_section_2')));
    await tester.pumpAndSettle();
    expect(find.text('AI 数据分析 · DeepSeek'), findsOneWidget);
    expect(find.textContaining('未连接后端'), findsOneWidget);
  });
}
