import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('导图四面板固定于同一屏，内容各自滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomePage(app: app, onTab: (_) {})),
    ));
    await tester.pumpAndSettle();

    expect(find.text('公司10大重要事项'), findsOneWidget);
    expect(find.text('公司10大任务派发'), findsOneWidget);
    expect(find.text('个人10大信息'), findsOneWidget);
    expect(find.text('日志展示'), findsOneWidget);
    // 不存在第五个整个首页的滚动容器；4 个 ListView 各属一面板。
    expect(find.byType(ListView), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
