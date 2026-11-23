import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/view_page.dart';
import 'package:mobile/screens/dispatch_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('默认日历只展示任务，不出现日志状态或日志统计', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app)));
    await tester.pumpAndSettle();

    expect(find.text('日历视图'), findsWidgets);
    expect(find.text('有日志'), findsNothing);
    expect(find.text('工作日志'), findsNothing);
    expect(find.textContaining('日志'), findsNothing);
    expect(find.byKey(const Key('view_create_task')), findsOneWidget);
  });

  testWidgets('任务创建入口在日历与任务清单上始终可见且不重复', (tester) async {
    final app = AppState();
    await tester.runAsync(() => app.login('demo001', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app)));
    await tester.pumpAndSettle();

    expect(find.text('创建任务'), findsOneWidget);
    await tester.tap(find.text('任务清单'));
    await tester.pumpAndSettle();
    expect(find.text('创建任务'), findsOneWidget);
    expect(find.byKey(const Key('view_create_task')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view_create_task')));
    await tester.pumpAndSettle();
    expect(find.byType(DispatchPage), findsOneWidget);
    expect(find.text('任务派发申请'), findsOneWidget);
  });
}
