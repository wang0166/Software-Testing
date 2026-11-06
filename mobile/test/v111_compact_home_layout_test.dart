import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in <Size>[
    const Size(390, 780),
    const Size(390, 600),
    const Size(320, 540),
  ]) {
    testWidgets('首页每日事项在 ${size.width}x${size.height} 下不溢出',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = AppState();
      await tester.runAsync(() => app.login('demo001', 'demo123456'));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        SafeArea(child: HomePage(app: app, onTab: (_) {})))));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event_history_panel')), findsOneWidget);
      expect(find.byKey(const Key('task_board_panel')), findsOneWidget);
      expect(find.byKey(const Key('daily_todo_month_grid')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
