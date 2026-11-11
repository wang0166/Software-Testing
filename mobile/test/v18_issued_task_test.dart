import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';
import 'package:mobile/screens/tasks_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('普通员工能查看自己提交的派发申请、修改并撤回', () async {
    final repo=MockRepository();
    await repo.login('demo001','demo123456');
    final members=await repo.companyMembers();
    final target=members.firstWhere((e)=>e.role=='TEAM_LEADER');
    final state=await repo.submitDispatchRequest(
      name:'部门协作需求',details:'确认跨层级需求及验收内容',
      startDate:'2026-11-05T10:30:00', deadline:'2026-11-07T17:45:00',
      urgency:'NOT_URGENT',taskType:'PRODUCT',assigneeIds:[target.id]);
    expect(state,'PENDING');
    final issued=(await repo.issuedTasks()).items;
    final request=issued.singleWhere((e)=>e.isRequest);
    expect(request.reviewStatus,'PENDING');
    expect(request.assigneeIds,contains(target.id));
    expect(await repo.requestIssuedTaskEdit(request,
      name:'部门协作需求（二次修改）',details:'更新范围，仍须审核',
      startDate:'2026-11-05T10:30:00', deadline:'2026-11-08T18:05:00',
      urgency:'URGENT',taskType:'PRODUCT',assigneeIds:[target.id]),'PENDING');
    final changed=(await repo.issuedTasks()).items.singleWhere((e)=>e.isRequest);
    expect(changed.name,'部门协作需求（二次修改）');
    expect(changed.stateLabel,'派发待审核');
    expect((await repo.tasks(personal:false)).where((e)=>e.name.contains('协作需求')),isEmpty);
    expect(await repo.requestIssuedTaskDelete(changed),'WITHDRAWN');
    expect((await repo.issuedTasks()).items.where((e)=>e.isRequest),isEmpty);
  });

  test('已发布任务修改与删除不能绕过审核，且不能重复申请', () async {
    final repo=MockRepository();
    await repo.login('leader','demo123456');
    final member=(await repo.recipients()).first;
    await repo.dispatchTask(name:'专项工作复盘',details:'整理每周汇总和目标',
      startDate:'2026-11-05T09:00:00',deadline:'2026-11-10T18:00:00',
      urgency:'NOT_URGENT',assigneeIds:[member.id]);
    final current=(await repo.issuedTasks()).items.singleWhere((e)=>!e.isRequest);
    expect(current.name,'专项工作复盘');
    expect(await repo.requestIssuedTaskEdit(current,
      name:'改名后的专项工作复盘',details:'需要审核的修改',
      startDate:'2026-11-05T09:00:00',deadline:'2026-11-11T18:30:00',
      urgency:'URGENT',taskType:'GENERAL',assigneeIds:[member.id]),'PENDING');
    final unchanged=(await repo.issuedTasks()).items.singleWhere((e)=>!e.isRequest);
    expect(unchanged.name,'专项工作复盘');
    expect(unchanged.changePending,isTrue);
    expect(()=>repo.requestIssuedTaskDelete(unchanged),throwsA(isA<AppFailure>()));
  });

  test('已发布任务删除需要审批，不会立即消失', () async {
    final repo=MockRepository();
    await repo.login('leader','demo123456');
    final member=(await repo.recipients()).first;
    await repo.dispatchTask(name:'发布记录待删除',details:'审核前不实际删除',
      startDate:'2026-11-05T09:00:00',deadline:'2026-11-10T18:00:00',
      urgency:'NOT_URGENT',assigneeIds:[member.id]);
    final task=(await repo.issuedTasks()).items.singleWhere((e)=>!e.isRequest);
    expect(await repo.requestIssuedTaskDelete(task),'PENDING');
    final pending=(await repo.issuedTasks()).items.singleWhere((e)=>!e.isRequest);
    expect(pending.changePending,isTrue);
    expect(pending.name,'发布记录待删除');
  });

  testWidgets('任务清单改为一张表，并以来源筛选接收/发布记录', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: TasksPage(app: app))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('received_tasks_tab')), findsNothing);
    expect(find.byKey(const Key('issued_tasks_tab')), findsNothing);
    expect(find.text('任务执行台账'), findsOneWidget);
    expect(find.byKey(const Key('task_ledger_horizontal')), findsOneWidget);
    expect(find.byKey(const Key('task_ledger_vertical')), findsOneWidget);
  });
}
