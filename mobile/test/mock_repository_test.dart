import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {SharedPreferences.setMockInitialValues({});});
  test('演示登录与恢复会话', () async {
    final repo=MockRepository();
    final user=await repo.login('demo001','demo123456');
    expect(user.role,'EMPLOYEE');
    expect((await MockRepository().restore())?.username,'demo001');
    await repo.logout();
    expect(await repo.restore(),isNull);
  });
  test('错误密码会被拒绝',() async {
    final repo=MockRepository();
    expect(()=>repo.login('demo001','wrong'),throwsA(isA<AppFailure>()));
  });
  test('员工不能查看其他人的日志',() async {
    final repo=MockRepository();
    final user=await repo.login('demo001','demo123456');
    final logs=await repo.logs();
    expect(logs.every((log)=>log.authorId==user.id),isTrue);
  });
  test('创始人日志按部门包含多个组织', () async {
    final repo = MockRepository();
    await repo.login('founder', 'demo123456');
    final logs = await repo.logs();
    expect(logs.map((l) => l.departmentName).toSet(), containsAll(['技术研发部', '产品设计部']));
  });
  test('自主修改密码验证原密码、强度和账号隔离，无需审批', () async {
    final repo = MockRepository();
    const next = 'Cloud!Orbit7River';
    await repo.login('demo001', 'demo123456');
    await expectLater(repo.changePassword(currentPassword: 'wrong', newPassword: next),
      throwsA(isA<AppFailure>()));
    await expectLater(repo.changePassword(currentPassword: 'demo123456', newPassword: 'weak'),
      throwsA(isA<AppFailure>()));
    await repo.changePassword(currentPassword: 'demo123456', newPassword: next);
    await expectLater(repo.changePassword(currentPassword: next, newPassword: next),
      throwsA(isA<AppFailure>()));
    await repo.logout();
    await expectLater(repo.login('demo001', 'demo123456'), throwsA(isA<AppFailure>()));
    expect((await repo.login('demo001', next)).username, 'demo001');
    await repo.logout();
    expect((await repo.login('demo002', 'demo123456')).username, 'demo002');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((key) => prefs.get(key) == next), isFalse);
  });
  test('未登录和已停用员工不能修改密码', () async {
    final disabled = <int>{};
    final repo = MockRepository(disabledUserIds: disabled);
    const next = 'Cloud!Orbit7River';
    await expectLater(repo.changePassword(currentPassword: 'demo123456', newPassword: next),
      throwsA(isA<AppFailure>()));
    await repo.login('demo001', 'demo123456');
    disabled.add(12);
    await expectLater(repo.changePassword(currentPassword: 'demo123456', newPassword: next),
      throwsA(isA<AppFailure>()));
  });
  test('管理员不可写日志',() async {
    final repo=MockRepository();
    await repo.login('admin','demo123456');
    expect(()=>repo.saveLog('test'),throwsA(isA<AppFailure>()));
  });
}
