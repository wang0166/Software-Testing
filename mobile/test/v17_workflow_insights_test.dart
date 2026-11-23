import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/insight_metrics.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/screens/personal_board_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('个人十大信息内容可持久化编辑，不与他人账号混淆', () async {
    expect(await PersonalBoardStorage.read(12), isNull);
    expect(await PersonalBoardStorage.write(12, [
      const PersonalBoardEntry(title: '产品评审', detail: '细节可随时更改'),
    ]), isTrue);
    final entries = await PersonalBoardStorage.read(12);
    expect(entries, hasLength(1));
    expect(entries!.first.detail, '细节可随时更改');
    expect(await PersonalBoardStorage.read(13), isNull);
    expect(await PersonalBoardStorage.write(12, []), isTrue);
    expect(await PersonalBoardStorage.read(12), isEmpty);
  });

  test('关键词分数按规则统计，紧急任务权重高于普通任务', () {
    const logs = [
      WorkLog(id: 1, authorId: 1, authorName: '甲', logDate: '2026-10-30',
        content: '今天完成联调，下一步测试联调', status: 'SUBMITTED'),
    ];
    const tasks = [
      TaskItem(id: 1, name: '紧急联调', details: '项目发布',
        status: 'IN_PROGRESS', source: 'RECEIVED', urgency: 'URGENT'),
    ];
    final words = extractWorkKeywords(logs: logs, tasks: tasks);
    final joint = words.firstWhere((e) => e.term == '联调');
    expect(joint.occurrences, 3);
    expect(joint.score, 5); // 2 from logs, 3 from urgent task
  });

  test('任务完成率与紧急占比不伪造数值', () {
    const tasks = [
      TaskItem(id: 1, name: '任务A', details: '', status: 'COMPLETED',
        source: 'RECEIVED', urgency: 'URGENT'),
      TaskItem(id: 2, name: '任务B', details: '', status: 'IN_PROGRESS',
        source: 'RECEIVED', urgency: 'NOT_URGENT'),
    ];
    expect(urgentTaskCount(tasks), 1);
    final counts = countTaskStatuses(tasks);
    expect(counts.completed, 1);
    expect(counts.inProgress, 1);
    expect(completionRatio(const DispatchedTask(id: 1, name: '任务',
      details: '', urgency: 'URGENT', startDate: '', deadline: '',
      assigneeCount: 0)), isNull);
    expect(completionRatio(const DispatchedTask(id: 2, name: '任务',
      details: '', urgency: 'URGENT', startDate: '', deadline: '',
      assigneeCount: 4, completedCount: 3)), 0.75);
  });
}
