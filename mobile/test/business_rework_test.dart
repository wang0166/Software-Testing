import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/data/mock_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('任务类型能解析并保留标签', () {
    final task = TaskItem.fromJson({'assignmentId':23,'name':'任务','taskType':'TESTING'},source:'RECEIVED');
    expect(task.taskType, 'TESTING');
    expect(taskTypeLabel(task.taskType), '测试');
  });

  test('演示模式公司首页四大面板有直接展示内容', () async {
    final repo = MockRepository();
    await repo.login('founder', 'demo123456');
    expect((await repo.companyMatters()).length, 10);
    expect((await repo.companyImportantTasks()).length, 10);
    expect((await repo.logs()).isNotEmpty, true);
  });

  test('普通员工可选公司成员创建待审核请求，但不直接生成接收任务', () async {
    final repo = MockRepository();
    await repo.login('demo001','demo123456');
    final people = await repo.companyMembers();
    expect(people.any((u) => u.role == 'FOUNDER'), isTrue);
    final before = (await repo.tasks(personal:false)).length;
    final response = await repo.submitDispatchRequest(
      name:'项目方案评审',details:'请审核跨层级项目方案',
      startDate:'2026-11-01T09:30:00',deadline:'2026-11-02T18:00:00',
      urgency:'NOT_URGENT',taskType:'PRODUCT',
      assigneeIds:[people.firstWhere((u) => u.role == 'FOUNDER').id],
    );
    expect(response,'PENDING');
    expect((await repo.tasks(personal:false)).length,before);
  });

  test('演示模式近三天日志允许重新编辑', () async {
    final repo = MockRepository();
    final me = await repo.login('demo001','demo123456');
    final date = todayChina;
    final existing = (await repo.logs(date:date)).where((l) => l.authorId == me.id).toList();
    final saved = await repo.saveLog('本日进度已更新',date:date,id:existing.isEmpty ? null : existing.first.id);
    expect(saved.content,'本日进度已更新');
    final edited = await repo.saveLog('复查后修订日志',date:date,id:saved.id);
    expect(edited.content,'复查后修订日志');
  });
}
