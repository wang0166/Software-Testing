import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/task_progress_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AppState, List<TaskItem>)> demoTasks(WidgetTester tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    final tasks = await tester.runAsync(() => app.repo.tasks(personal: false));
    return (app, tasks!);
  }

  testWidgets('未完成任务只有一个“标记为已完成”操作，确认前不修改状态',
      (tester) async {
    final (app, tasks) = await demoTasks(tester);
    final task = tasks.firstWhere((t) => t.status != 'COMPLETED');
    await tester.pumpWidget(MaterialApp(
      home: TaskProgressPage(app: app, task: task),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task_mark_completed')), findsOneWidget);
    expect(find.byKey(const Key('task_status_in_progress')), findsNothing);
    expect(find.byKey(const Key('task_status_completed')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('task_mark_completed')));
    await tester.tap(find.byKey(const Key('task_mark_completed')));
    await tester.pumpAndSettle();
    expect(find.text('确认任务已完成？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task_mark_completed')), findsOneWidget);
    final unchanged = await tester.runAsync(() => app.repo.tasks(personal: false));
    expect(unchanged!.firstWhere((t) => t.id == task.id).status,
      isNot('COMPLETED'));
  });

  testWidgets('确认完成后只显示状态和服务端记录的完成时间，保留审核申请',
      (tester) async {
    final (app, tasks) = await demoTasks(tester);
    final task = tasks.firstWhere((t) => t.status != 'COMPLETED');
    await tester.pumpWidget(MaterialApp(
      home: TaskProgressPage(app: app, task: task),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('task_mark_completed')));
    await tester.tap(find.byKey(const Key('task_mark_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认完成'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task_mark_completed')), findsNothing);
    expect(find.text('完成时间'), findsOneWidget);
    expect(find.text('等待后端同步'), findsNothing);
    expect(find.text('申请完成检查'), findsOneWidget);
    final updated = await tester.runAsync(() => app.repo.tasks(personal: false));
    expect(updated!.firstWhere((t) => t.id == task.id).status, 'COMPLETED');
    final history = await tester.runAsync(() => app.repo.taskProgressHistory(task.id));
    expect(history!.any((r) => r.status == 'COMPLETED' && r.createdAt.isNotEmpty),
      isTrue);
  });

  testWidgets('已经完成的任务不显示“标记为已完成”按钮', (tester) async {
    final (app, tasks) = await demoTasks(tester);
    final task = tasks.firstWhere((t) => t.status == 'COMPLETED');
    await tester.pumpWidget(MaterialApp(
      home: TaskProgressPage(app: app, task: task),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task_mark_completed')), findsNothing);
    expect(find.text('完成时间'), findsOneWidget);
  });
}
