import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/daily_todos.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/data/api_repository.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';
import 'package:mobile/screens/daily_todos_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _submit(MockRepository repo, List<int> recipients) =>
  repo.submitDispatchRequest(
    name: '跨部门协作', details: '跟进测试清单', startDate: '2026-11-06T09:00:00',
    deadline: '2026-11-08T17:00:00', urgency: 'NOT_URGENT',
    taskType: 'TESTING', assigneeIds: recipients,
  );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('单日旧数据默认全天，跨日事项保持实际跨度及原起止时间', () {
    final legacy = DailyTodo.fromJson({'id': '1', 'date': '2026-11-04', 'title': '旧事项'});
    expect(legacy.endDate, legacy.date);
    expect(legacy.startTime, isNull);
    const original = DailyTodo(id: '2', date: '2026-11-29', endDate: '2026-12-02',
      title: '测试计划', note: '原说明', completed: true, startTime: '21:00', endTime: '08:30');
    final moved = original.moveTo('2027-03-14', fromDate: '2026-12-01');
    expect(moved.date, '2027-03-12');
    expect(moved.endDate, '2027-03-15');
    expect(moved.overlaps(from: '2027-03-14', to: '2027-03-14'), isTrue);
    expect(moved.overlaps(from: '2027-03-16', to: '2027-03-31'), isFalse);
    expect(moved.startTime, '21:00');
    expect(moved.endTime, '08:30');
    expect(moved.completed, isTrue);
    expect(DailyTodo.validTimeRange('20:00', '08:00'), isFalse);
    expect(DailyTodo.validTimeRange('20:00', '08:00', acrossDays: true), isTrue);
    expect(DailyTodo.validTimeRange('10:00', null), isFalse);
    expect(DailyTodo.validDate('2026-02-30'), isFalse);
  });

  testWidgets('长按后停留在右缘可连续翻三个月并在新月份放下', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateUtils.dateOnly(chinaNow);
    final day = dayString(today);
    const storage = DailyTodoStorage(310);
    await storage.write([
      DailyTodo(id: 'move', date: day,
        endDate: dayString(DateTime(today.year, today.month, today.day + 2)),
        title: '跨月事项', startTime: '09:00', endTime: '10:00'),
    ]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 675, child: DailyTodosCalendar(userId: 310)),
    )));
    await tester.pumpAndSettle();

    final source = find.byKey(Key('daily_todo_drag_calendar_${day}_move'));
    final edge = find.byKey(const Key('daily_todo_drag_next_edge'));
    final drag = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 550));
    await drag.moveTo(tester.getCenter(edge));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 650));
    }
    final target = DateTime(today.year, today.month + 3, 15);
    expect(find.text('${target.year}年${target.month}月'), findsOneWidget);
    final drop = find.byKey(Key('daily_todo_drop_${dayString(target)}'));
    await drag.moveTo(tester.getCenter(drop));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    final saved = (await storage.read()).single;
    expect(saved.date, dayString(target));
    expect(saved.endDate, dayString(DateTime(target.year, target.month, 17)));
    expect(saved.startTime, '09:00');
    expect(saved.endTime, '10:00');
    expect(tester.takeException(), isNull);
  });

  test('全公司成员含本人，一次派发只由申请人的直属上级审核', () async {
    final repo = MockRepository();
    final employee = await repo.login('demo001', MockRepository.demoPassword);
    final members = await repo.companyMembers();
    final otherTeam = members.singleWhere((user) => user.username == 'product01');
    expect(members.map((user) => user.id), contains(employee.id));
    expect(await _submit(repo, [employee.id, otherTeam.id]), 'PENDING');
    final request = (await repo.issuedTasks()).items.single;
    Future<List<TaskItem>> published() async => (await repo.tasks(personal: false))
      .where((task) => task.name == '跨部门协作').toList();
    expect(await published(), isEmpty);

    await repo.login('manager', MockRepository.demoPassword);
    expect(await repo.dispatchReviewInbox(), isEmpty);
    await expectLater(repo.reviewDispatchRequest(request.id, approve: true),
      throwsA(isA<AppFailure>()));

    await repo.login('leader', MockRepository.demoPassword);
    final pending = (await repo.dispatchReviewInbox()).single;
    expect(request.reviewerName, '周知夏');
    expect(pending.request.id, request.id);
    expect(pending.assigneeNames, containsAll([employee.name, otherTeam.name]));
    await repo.reviewDispatchRequest(request.id, approve: true);
    await expectLater(repo.reviewDispatchRequest(request.id, approve: true),
      throwsA(isA<AppFailure>()));
    expect(await repo.dispatchReviewInbox(), isEmpty);

    await repo.login(employee.username, MockRepository.demoPassword);
    final own = (await published()).single;
    expect(own.taskType, 'TESTING');
    expect((await repo.issuedTasks()).items.single.id, own.taskId);
    await repo.login(otherTeam.username, MockRepository.demoPassword);
    expect((await published()).single.taskId, own.taskId);
  });

  test('停用状态标记保留原有任务和日志，并从新派发候选移除', () async {
    final disabled = <int>{};
    final repo = MockRepository(disabledUserIds: disabled);
    await repo.login('leader', MockRepository.demoPassword);
    final before = (await repo.subordinatesTaskOverview()).singleWhere((m) => m.userId == 12);
    final logged = (await repo.logs()).where((log) => log.authorId == before.userId).toList();
    expect(before.tasks, isNotEmpty);
    expect(logged, isNotEmpty);
    disabled.add(before.userId);
    final after = (await repo.subordinatesTaskOverview()).singleWhere((m) => m.userId == before.userId);
    expect(after.isActive, isFalse);
    expect(after.tasks.map((task) => task.id), before.tasks.map((task) => task.id));
    expect((await repo.logs()).where((log) => log.authorId == before.userId).map((log) => log.id),
      logged.map((log) => log.id));
    expect((await repo.companyMembers()).map((user) => user.id), isNot(contains(before.userId)));
    await expectLater(_submit(repo, [before.userId]), throwsA(isA<AppFailure>()));
    await expectLater(repo.login('demo001', MockRepository.demoPassword), throwsA(isA<AppFailure>()));
    expect(SubordinateTaskSummary.fromJson({'userId': 12, 'active': false}).isActive, isFalse);
  });

  test('云端事项请求携带结束日期和起止时间，旧响应不能误报保存成功', () async {
    var omitRange = false;
    final repo = ApiRepository(baseUrl: 'https://example.test/api', client: MockClient((request) async {
      expect(request.url.path, '/api/daily-items');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['date'], '2026-12-01');
      expect(body['endDate'], '2026-12-02');
      expect(body['startTime'], '09:00');
      expect(body['endTime'], '11:00');
      return http.Response(jsonEncode({
        'code': 0,
        'data': {'id': 1, if (!omitRange) ...body, 'date': body['date'], 'title': body['title']},
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    Future<DailyTodo> save() => repo.createDailyItem(date: '2026-12-01',
      endDate: '2026-12-02', startTime: '09:00', endTime: '11:00', title: '同步事项');
    expect((await save()).endDate, '2026-12-02');
    omitRange = true;
    await expectLater(save(), throwsA(isA<AppFailure>()));
  });
}
