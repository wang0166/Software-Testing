
class MockUser {
  final String username;
  final String displayName;
  final String role;

  const MockUser({
    required this.username,
    required this.displayName,
    required this.role,
  });
}

class MockAuthService {
  static const String demoUsername = 'demo001';
  static const String demoPassword = 'demo123456';

  Future<MockUser> login({
    required String username,
    required String password,
  }) async {
    // 模拟网络请求耗时
    await Future<void>.delayed(
      const Duration(milliseconds: 600),
    );

    if (username == demoUsername &&
        password == demoPassword) {
      return const MockUser(
        username: demoUsername,
        displayName: '演示员工',
        role: 'EMPLOYEE',
      );
    }

    throw Exception('账号或密码错误');
  }
}