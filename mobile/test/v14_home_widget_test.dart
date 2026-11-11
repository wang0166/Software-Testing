import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('首页事件纪、任务看板、每日事项同屏展示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomePage(app: app, onTab: (_) {})),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('事件纪'), findsOneWidget);
    expect(find.text('任务看板'), findsOneWidget);
    expect(find.text('每日事项'), findsOneWidget);
    expect(find.text('个人10大信息'), findsNothing);
    expect(find.text('日志展示'), findsNothing);
    expect(find.byKey(const Key('daily_todo_month_grid')), findsOneWidget);
    expect(find.byType(ListView), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
