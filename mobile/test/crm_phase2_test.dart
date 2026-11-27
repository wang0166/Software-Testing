import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/models.dart';
import 'package:mobile/core/app_state.dart';
import 'package:mobile/crm/crm_gateway.dart';
import 'package:mobile/crm/crm_models.dart';
import 'package:mobile/screens/crm_customers_page.dart';
import 'package:mobile/screens/employee_archive_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const founder = UserProfile(id: 1, username: 'founder', name: '负责人', role: 'FOUNDER');
  const manager = UserProfile(id: 3, username: 'manager', name: '经理',
    role: 'DEPT_MANAGER', departmentId: 3);
  const staff = UserProfile(id: 12, username: 'demo001', name: '员工',
    role: 'EMPLOYEE', departmentId: 3);
  const disabled = UserProfile(id: 12, username: 'demo001', name: '员工',
    role: 'EMPLOYEE', departmentId: 3, isActive: false);

  test('不同岗位的客户、敏感信息及合同权限分离', () {
    expect(CrmAccess.forUser(founder).contracts, isTrue);
    expect(CrmAccess.forUser(founder).sensitiveCustomers, isTrue);
    expect(CrmAccess.forUser(manager).contractAlerts, isTrue);
    expect(CrmAccess.forUser(manager).contracts, isFalse);
    expect(CrmAccess.forUser(manager).revenue, isFalse);
    expect(CrmAccess.forUser(staff).employees, isFalse);
    expect(CrmAccess.forUser(staff).revenue, isFalse);
    expect(CrmAccess.forUser(disabled).customers, isFalse);
    expect(CrmAccess.forUser(const UserProfile(
      id: 91, username: 'outsider', name: '其他', role: 'UNKNOWN')).customers, isFalse);
  });

  test('客户分部门分配范围，并且分页、筛选有效', () async {
    final gateway = DemoCrmGateway();
    final all = await gateway.customers(founder, page: 1, size: 2);
    expect(all.items.length, 2);
    expect(all.total, 5);
    expect(all.hasMore, isTrue);
    final later = await gateway.customers(founder, page: 3, size: 2);
    expect(later.items.length, 1);
    expect(later.hasMore, isFalse);
    final own = await gateway.customers(staff);
    expect(own.items.length, 1);
    expect(own.items.single.id, 'C-003');
    final dept = await gateway.customers(manager);
    expect(dept.items.every((e) => e.departmentId == 3 && !e.sensitive), isTrue);
    const leader = UserProfile(id: 8, username: 'leader', name: '组长',
      role: 'TEAM_LEADER', departmentId: 3, teamId: 8);
    final team = await gateway.customers(leader);
    expect(team.items.map((c) => c.id).toSet(), {'C-001','C-003'});
    final companies = await gateway.customers(founder, category: 'COMPANY');
    expect(companies.total, 2);
    final matched = await gateway.customers(founder, search: '云杉');
    expect(matched.items.single.id, 'C-002');
  });

  test('权益核销有上限、业务记录保留多名参与人员', () async {
    final gateway = DemoCrmGateway();
    final before = (await gateway.benefits(founder, 'C-001')).first;
    expect(before.remaining, 3);
    final updated = await gateway.consumeBenefit(founder, before.id);
    expect(updated.used, 2);
    final task = await gateway.addActivity(founder, customerId: 'C-001',
      kind: 'VISIT', title: '企业参访联络', date: '2026-12-13',
      status: 'PLANNED', participantIds: [8, 12, 12]);
    expect(task.participantIds, [8, 12]);
    expect((await gateway.customerActivities(founder, 'C-001'))
      .any((a) => a.id == task.id), isTrue);
    await expectLater(gateway.consumeBenefit(staff, before.id), throwsA(isA<Exception>()));
    for (var i = 0; i < 2; i++) {
      await gateway.consumeBenefit(founder, before.id);
    }
    await expectLater(gateway.consumeBenefit(founder, before.id), throwsA(isA<Exception>()));
    final annual = await gateway.consumeBenefit(founder, 'B-03');
    expect(annual.used, 4);
    final afterCustomer = await gateway.customers(founder, search: 'C-003');
    expect(afterCustomer.items.single.annualCardUsed, 4);
    final revenue = await gateway.revenueSummary(founder);
    expect(revenue.byBusinessFen.values.reduce((a,b) => a+b), revenue.totalAmountFen);
    await expectLater(gateway.revenueSummary(staff), throwsA(isA<Exception>()));
  });

  test('员工合同日期提醒不包含离职员工和已过期日期', () async {
    final gateway = DemoCrmGateway();
    final page = await gateway.employees(founder, expiringOnly: true);
    expect(page.items.length, 2);
    expect(page.items.every((e) => e.contractExpiring(DateTime.now())), isTrue);
    final gatewayWithDisabled = DemoCrmGateway(disabledUserIds: {12});
    final pending = await gatewayWithDisabled.employees(founder, expiringOnly: true);
    expect(pending.items.every((e) => e.id != 12), isTrue);
    expect(const EmployeeArchive(id: 42, departmentId: 1, name: '测试',
      department: '运营部', duty: '协助', role: 'EMPLOYEE',
      accountStatus: 'DISABLED', contractEnd: '2026-12-01',
      contractArchiveStatus: 'ARCHIVED').contractExpiring(DateTime(2026, 11, 24)), isFalse);
  });

  testWidgets('手机窄屏 CRM 列表及档案页面没有 Flutter 异常', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CrmCustomersPage(app: app))));
    await tester.pumpAndSettle();
    expect(find.text('客户与会员'), findsOneWidget);
    expect(find.byKey(const Key('crm_customer_list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: EmployeeArchivePage(app: app))));
    await tester.pumpAndSettle();
    expect(find.text('人员与业务档案'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增客户弹窗退场后才释放输入控件', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState();
    await tester.runAsync(() => app.login('founder', 'demo123456'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CrmCustomersPage(app: app))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('crm_add_customer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('crm_customer_name')), '新增长名称客户');
    await tester.enterText(find.byKey(const Key('crm_customer_remark')), '用于验证弹窗退场生命周期');
    await tester.tap(find.byKey(const Key('crm_customer_save')));
    await tester.pumpAndSettle();

    expect(find.text('客户档案已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
