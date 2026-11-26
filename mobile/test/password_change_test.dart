import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/password_policy.dart';
import 'package:mobile/data/api_repository.dart';
import 'package:mobile/data/mock_repository.dart';
import 'package:mobile/data/repository.dart';
import 'package:mobile/screens/password_change_page.dart';

const _strong = 'Cloud!Orbit7River';

class _RecordingRepo extends MockRepository {
  int calls = 0;
  String? current;
  String? next;
  bool fail = true;
  @override
  Future<void> changePassword({required String currentPassword,
    required String newPassword}) async {
    calls++;
    current = currentPassword;
    next = newPassword;
    if (fail) throw const AppFailure('原密码错误');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('密码强度规则检查长度、字符类型和常见弱密码片段', () {
    for (final value in ['', 'abc', 'longlowercaseonly', 'Cloud!OrbitRiver',
      'Cloud7OrbitRiver', 'Password123456!', '${_strong}\n',
      List.filled(129, 'A').join()]) {
      expect(PasswordPolicy(value).isStrong, isFalse);
      expect(PasswordPolicy(value).error, isNotNull);
    }
    expect(PasswordPolicy(_strong).isStrong, isTrue);
    expect(PasswordPolicy(_strong).error, isNull);
  });

  test('真实接口只发送自助改密请求，并要求服务端明确确认', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final sent = <http.Request>[];
    var status = 'PENDING';
    var reject = false;
    final client = MockClient((request) async {
      sent.add(request);
      if (request.url.path == '/api/auth/login') {
        return http.Response(jsonEncode({'code': 0, 'data': {
          'accessToken': 'test-access', 'refreshToken': 'test-refresh',
          'user': {'id': 12, 'username': 'demo001', 'role': 'EMPLOYEE'},
        }}), 200);
      }
      if (reject) {
        return http.Response(jsonEncode({'code': 400, 'message': '原密码错误'}), 400);
      }
      return http.Response(jsonEncode({'code': 0, 'data': {'status': status}}), 200);
    });
    final repo = ApiRepository(baseUrl: 'https://example.test/api', client: client);
    addTearDown(client.close);
    await expectLater(repo.changePassword(currentPassword: 'old', newPassword: _strong),
      throwsA(isA<AppFailure>()));
    expect(sent, isEmpty);
    await repo.login('demo001', 'old');
    await expectLater(repo.changePassword(currentPassword: 'old', newPassword: 'weak'),
      throwsA(isA<AppFailure>()));
    expect(sent.length, 1);
    await expectLater(repo.changePassword(currentPassword: 'old', newPassword: _strong),
      throwsA(isA<AppFailure>()));
    status = 'CHANGED';
    reject = true;
    await expectLater(repo.changePassword(currentPassword: 'old', newPassword: _strong),
      throwsA(isA<AppFailure>()));
    reject = false;
    await repo.changePassword(currentPassword: 'old', newPassword: _strong);
    final changes = sent.skip(1).toList();
    expect(changes.length, 3);
    for (final request in changes) {
      expect(request.url.path, '/api/account/password-change');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer test-access');
      expect(jsonDecode(request.body), {'currentPassword': 'old', 'newPassword': _strong});
    }
  });

  testWidgets('窄屏实时强度检测、确认密码及失败重试', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _RecordingRepo();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(builder: (_) => PasswordChangePage(repo: repo)),
            ),
            child: const Text('打开修改密码'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('打开修改密码'));
    await tester.pumpAndSettle();
    final current = find.byKey(const Key('password_current'));
    final next = find.byKey(const Key('password_new'));
    final confirm = find.byKey(const Key('password_confirm'));
    final submit = find.byKey(const Key('password_submit'));
    await tester.enterText(current, 'demo123456');
    await tester.enterText(next, 'weak');
    await tester.pump();
    expect(find.text('密码强度：弱'), findsOneWidget);
    await tester.enterText(next, _strong);
    await tester.pump();
    expect(find.text('密码强度：强（符合规则）'), findsOneWidget);
    await tester.scrollUntilVisible(confirm, 150,
      scrollable: find.byType(Scrollable).first);
    await tester.enterText(confirm, 'not-matching');
    await tester.pump();
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
    await tester.scrollUntilVisible(submit, 120,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.ensureVisible(confirm);
    await tester.enterText(confirm, _strong);
    await tester.pump();
    await tester.scrollUntilVisible(submit, 120,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.current, 'demo123456');
    expect(repo.next, _strong);
    expect(find.text('修改未确认成功，请检查原密码、登录状态和网络后重试。'), findsOneWidget);
    repo.fail = false;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('打开修改密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
