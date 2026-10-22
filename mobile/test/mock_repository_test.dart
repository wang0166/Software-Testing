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
  test('管理员不可写日志',() async {
    final repo=MockRepository();
    await repo.login('admin','demo123456');
    expect(()=>repo.saveLog('test'),throwsA(isA<AppFailure>()));
  });
}
