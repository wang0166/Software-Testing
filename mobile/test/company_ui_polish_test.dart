import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/screens/view_page.dart';
import 'package:mobile/screens/crm_customers_page.dart';
import 'package:mobile/screens/employee_archive_page.dart';
import 'package:mobile/screens/task_handover_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('公司六个入口无需横向滑动即可访问', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app)));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('company_tab_$i')), findsOneWidget);
    }
    final crmTab = find.byKey(const Key('company_tab_4'));
    final archiveTab = find.byKey(const Key('company_tab_5'));
    expect(tester.getTopLeft(crmTab).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('company_tab_0'))).dy));
    expect(tester.getTopLeft(crmTab).dy,
      closeTo(tester.getTopLeft(archiveTab).dy, 1));
    await tester.tap(crmTab);
    await tester.pump();
    expect(find.byType(CrmCustomersPage), findsOneWidget);
    await tester.tap(archiveTab);
    await tester.pump();
    expect(find.byType(EmployeeArchivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('交接状态统一下拉筛选，不再出现突兀独立按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('leader', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: ViewPage(app: app)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('company_tab_1')));
    await tester.pump();
    expect(find.byKey(const Key('task_handover_filter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('task_handover_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待交接').last);
    await tester.pump();
    expect(find.byType(TaskHandoverInbox), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
