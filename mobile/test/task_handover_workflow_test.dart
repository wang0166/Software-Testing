import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('员工停用自动生成待交接，已完成任务不进入清单', () async {
    final disabled = <int>{12};
    final repo = MockRepository(disabledUserIds: disabled);
    await repo.login('leader', MockRepository.demoPassword);
    final rows = await repo.taskHandovers();
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.pending && r.originalUserId == 12), isTrue);
    expect(rows.any((r) => r.originalAssignmentId == 310), isTrue);
    expect(rows.any((r) => r.originalAssignmentId == 311), isFalse);
    expect((await repo.taskHandovers()).length, rows.length,
      reason: '刷新不应重复创建待交接记录');
    final candidates = await repo.handoverCandidates(rows.first.id);
    expect(candidates.map((u) => u.id), contains(13));
    expect(candidates.map((u) => u.id), isNot(contains(12)));
    await expectLater(repo.confirmTaskHandover(rows.first.id,
      newAssigneeId: 12, note: '不得分派给停用人员'), throwsA(isA<AppFailure>()));
  });

  test('主管交接保留原任务、进度、日志；新员工接收，不能重复交接', () async {
    final repo = MockRepository(disabledUserIds: {12});
    await repo.login('leader', MockRepository.demoPassword);
    final before = (await repo.subordinatesTaskOverview())
      .singleWhere((m) => m.userId == 12);
    final old = before.tasks.singleWhere((t) => t.id == 310);
    final oldLogs = (await repo.logs()).where((l) => l.authorId == 12)
      .map((l) => l.id).toList();
    final pending = (await repo.taskHandovers())
      .singleWhere((r) => r.originalAssignmentId == 310);
    final confirmed = await repo.confirmTaskHandover(pending.id,
      newAssigneeId: 13, note: '联调文档在共享空间，剩余验证失败请求');
    expect(confirmed.status, 'COMPLETED');
    expect(confirmed.newAssigneeId, 13);
    expect(confirmed.progressPercent, old.progressPercent);
    expect(confirmed.newAssignmentId, isNotNull);
    await expectLater(repo.confirmTaskHandover(pending.id,
      newAssigneeId: 13, note: '再次交接'), throwsA(isA<AppFailure>()));
    final after = (await repo.subordinatesTaskOverview())
      .singleWhere((m) => m.userId == 12);
    final historic = after.tasks.singleWhere((t) => t.id == 310);
    expect(historic.status, old.status);
    expect(historic.progressPercent, old.progressPercent);
    expect(historic.handoverStatus, 'COMPLETED');
    expect(historic.handoverToName, '陈星禾');
    expect((await repo.logs()).where((l) => l.authorId == 12)
      .map((l) => l.id).toList(), oldLogs);
    await repo.login('demo002', MockRepository.demoPassword);
    final incoming = (await repo.tasks(personal: false))
      .singleWhere((t) => t.id == confirmed.newAssignmentId);
    expect(incoming.name, old.name);
    expect(incoming.status, old.status);
    expect(incoming.progressPercent, old.progressPercent);
    final progress = await repo.taskProgressHistory(incoming.id);
    expect(progress, isNotEmpty);
    expect(progress.first.note, contains('交接'));
  });

  test('无权的普通员工无法查看或办理主管交接', () async {
    final repo = MockRepository(disabledUserIds: {12});
    await repo.login('demo002', MockRepository.demoPassword);
    expect(await repo.taskHandovers(), isEmpty);
    await expectLater(repo.handoverCandidates('12_310'),
      throwsA(isA<AppFailure>()));
    await expectLater(repo.confirmTaskHandover('12_310',
      newAssigneeId: 13, note: '越权交接'), throwsA(isA<AppFailure>()));
  });
}
