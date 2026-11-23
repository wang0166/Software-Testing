import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('任务模型解析进度百分比与受阻状态', () {
    final task=TaskItem.fromJson({
      'assignmentId':123,'name':'接口联调','details':'测试','executionStatus':'BLOCKED',
      'progressPercent':45,'progressNote':'等待权限审批',
      'deadline':'2020-01-01T18:00:00',
    },source:'RECEIVED');
    expect(task.progressPercent,45);
    expect(task.progressNote,'等待权限审批');
    expect(task.statusLabel,'受阻');
    expect(task.isOverdue,isTrue);
    expect(TaskItem.fromJson({'assignmentId':5},source:'RECEIVED').progressPercent,isNull);
  });

  test('进度填报验证：必须说明受阻原因且完成率合法', () {
    const task=TaskItem(id:9,name:'开发任务',details:'',status:'IN_PROGRESS',source:'RECEIVED',progressPercent:40);
    expect(taskProgressValidation(task,'BLOCKED',50,''),isNotNull);
    expect(taskProgressValidation(task,'IN_PROGRESS',100,'测试'),isNotNull);
    expect(taskProgressValidation(task,'COMPLETED',90,'测试'),isNotNull);
    expect(taskProgressValidation(task,'IN_PROGRESS',30,'测试'),isNotNull);
    expect(taskProgressValidation(task,'BLOCKED',60,'等待后端提供数据'),isNull);
  });

  test('演示进度更新持久化，历史记录包含作者、状态与备注', () async {
    final repo=MockRepository();
    await repo.login('demo001','demo123456');
    final task=(await repo.tasks(personal:false)).firstWhere((e)=>e.id==310);
    final initial=task.progressPercent??0;
    final desired=initial<80?80:90;
    await repo.updateTaskProgress(task,status:'IN_PROGRESS',percent:desired,note:'完成接口回归，继续测试');
    final latest=(await repo.tasks(personal:false)).firstWhere((e)=>e.id==310);
    expect(latest.progressPercent,desired);
    expect(latest.progressNote,'完成接口回归，继续测试');
    final history=await repo.taskProgressHistory(310);
    expect(history.length,1);
    expect(history.first.percent,desired);
    expect(history.first.authorName,'林小满');
    expect(history.first.note,'完成接口回归，继续测试');
    // A fresh repository in the same local demo session sees the stored data.
    final next=MockRepository();
    await next.login('demo001','demo123456');
    expect((await next.tasks(personal:false)).firstWhere((e)=>e.id==310).progressPercent,desired);
    expect((await next.taskProgressHistory(310)).length,1);
  });

  test('发布人可以查看接收人填报的完成率，不能直接篡改任务', () async {
    final repo=MockRepository();
    await repo.login('leader','demo123456');
    final employee=(await repo.recipients()).first;
    await repo.dispatchTask(name:'年度任务联调',details:'确认任务与日志互通',
      startDate:'2026-11-03T09:00:00',deadline:'2026-11-10T18:00:00',
      urgency:'URGENT',assigneeIds:[employee.id]);
    final issued=(await repo.issuedTasks()).items.singleWhere((e)=>!e.isRequest);
    await repo.login(employee.username,'demo123456');
    final received=(await repo.tasks(personal:false)).singleWhere((e)=>e.taskId==issued.id);
    await repo.updateTaskProgress(received,status:'IN_PROGRESS',percent:50,note:'已经完成前半部分');
    await repo.login('leader','demo123456');
    final reported=(await repo.dispatchedAssignments(issued.id)).singleWhere((e)=>e.assigneeId==employee.id);
    expect(reported.progressPercent,50);
    expect(reported.progressNote,'已经完成前半部分');
    await expectLater(repo.updateTaskProgress(received,status:'IN_PROGRESS',percent:70,note:'越权修改'),
      throwsA(isA<AppFailure>()));
  });

  test('不能修改其他人员的任务或伪造服务器审核', () async {
    final repo=MockRepository();
    await repo.login('demo001','demo123456');
    const fake=TaskItem(id:987654,name:'无权访问',details:'',status:'IN_PROGRESS',source:'RECEIVED');
    await expectLater(repo.updateTaskProgress(fake,status:'IN_PROGRESS',percent:50,note:'测试'),
      throwsA(isA<AppFailure>()));
    await expectLater(repo.taskProgressHistory(987654),throwsA(isA<AppFailure>()));
  });
}
