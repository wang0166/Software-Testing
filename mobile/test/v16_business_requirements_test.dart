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

  testWidgets('四宫格后两个信息模块具有独立编辑入口', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      HomePage(app: app, onTab: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_edit_03')), findsOneWidget);
    expect(find.byKey(const Key('home_edit_04')), findsOneWidget);
    expect(find.byKey(const Key('home_edit_01')), findsNothing);
  });

  testWidgets('AI 地图预留入口不会伪装成已经接入的 AI', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      TaskMapPage(app: app))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_map_section_2')));
    await tester.pumpAndSettle();
    expect(find.text('AI 数据分析 · 接口预留'), findsOneWidget);
  });
}
