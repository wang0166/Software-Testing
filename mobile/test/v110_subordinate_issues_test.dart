import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/core/task_issue_utils.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';
import 'package:mobile/widgets/subordinate_task_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  test('异常反馈按未解除的不同受阻记录计数，正常更新后归零',() async {
    final repo=MockRepository();
    await repo.login('demo001','demo123456');
    var item=(await repo.tasks(personal:false)).firstWhere((t)=>t.id==310);
    await repo.updateTaskProgress(item,status:'BLOCKED',percent:65,note:'异常一：授权返回 403');
    item=(await repo.tasks(personal:false)).firstWhere((t)=>t.id==310);
    await repo.updateTaskProgress(item,status:'BLOCKED',percent:70,note:'异常二：同步冲突');
    await repo.login('leader','demo123456');
    var list=await repo.subordinatesTaskOverview();
    var subordinate=list.firstWhere((e)=>e.userId==12);
    expect(subordinate.visibleIssueCount,2);
    expect(subordinate.tasks.firstWhere((t)=>t.id==310).visibleIssueCount,2);
    final history=await repo.subordinateTaskProgressHistory(12,310);
    expect(history.length,2);
    expect(history.first.note,contains('异常二'));

    await repo.login('demo001','demo123456');
    item=(await repo.tasks(personal:false)).firstWhere((t)=>t.id==310);
    await repo.updateTaskProgress(item,status:'IN_PROGRESS',percent:80,note:'异常已解决，继续推进');
    await repo.login('leader','demo123456');
    list=await repo.subordinatesTaskOverview();
    subordinate=list.firstWhere((e)=>e.userId==12);
    expect(subordinate.visibleIssueCount,0);
  });

  test('无管理权限和非管理范围禁止读取他人反馈历史',() async {
    final repo=MockRepository();
    await repo.login('demo002','demo123456');
    await expectLater(repo.subordinateTaskProgressHistory(12,310),throwsA(isA<AppFailure>()));
    await repo.login('productmanager','demo123456');
    await expectLater(repo.subordinateTaskProgressHistory(12,310),throwsA(isA<AppFailure>()));
    await repo.login('founder','demo123456');
    expect(await repo.subordinateTaskProgressHistory(12,310),isEmpty);
  });

  test('历史受阻已解除后不继续提示；普通进度备注不算异常',() {
    const t=TaskItem(id:310,name:'联调',details:'',status:'IN_PROGRESS',source:'RECEIVED',progressNote:'有反馈');
    expect(unresolvedIssueEvents(t,const []),0);
    final blocked=TaskItem.fromJson({'assignmentId':310,'executionStatus':'BLOCKED','name':'联调'},source:'RECEIVED');
    final history=[
      const TaskProgressRecord(id:2,status:'BLOCKED',note:'问题二',authorName:'员工',createdAt:'2026-11-02T12:00:00'),
      const TaskProgressRecord(id:1,status:'BLOCKED',note:'问题一',authorName:'员工',createdAt:'2026-11-02T11:00:00'),
    ];
    expect(unresolvedIssueEvents(blocked,history),2);
  });

  testWidgets('点击下属任务行可进入详情，异常数字在任务行可见',(tester) async {
    const task=TaskItem(id:310,name:'完成模块联调',details:'',source:'RECEIVED',
      status:'BLOCKED',openIssueCount:2,progressNote:'接口鉴权异常');
    var tapped=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      SubordinateTaskRow(task:task,onTap:()=>tapped=true))));
    expect(find.text('2'),findsOneWidget);
    expect(find.textContaining('问题反馈：'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('subordinate_task_310')));
    expect(tapped,isTrue);
  });
}
