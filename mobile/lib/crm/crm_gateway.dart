import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';
import '../data/repository.dart';
import 'crm_models.dart';

abstract class CrmGateway {
  Future<CrmRevenueSummary> revenueSummary(UserProfile user);
  Future<CrmPage<CrmCustomer>> customers(UserProfile user, {
    String search = '', String category = '', String business = '',
    int page = 1, int size = 20});
  Future<CrmCustomer> createCustomer(UserProfile user, {
    required String name, required String category, required String business,
    required String tier, String remark = ''});
  Future<List<CrmBenefit>> benefits(UserProfile user, String customerId);
  Future<CrmBenefit> consumeBenefit(UserProfile user, String benefitId);
  Future<List<CrmActivity>> customerActivities(UserProfile user, String customerId);
  Future<CrmActivity> addActivity(UserProfile user, {
    required String customerId, required String kind, required String title,
    required String date, required String status,
    required List<int> participantIds, String note = ''});
  Future<CrmPage<EmployeeArchive>> employees(UserProfile user, {
    String search = '', bool expiringOnly = false, int page = 1, int size = 20});
  Future<EmployeeArchive> createEmployee(UserProfile user, {
    required String name, required String department, required String duty,
    required String contractEnd});
  Future<List<CrmActivity>> employeeActivities(UserProfile user, int employeeId);
}

/// Demo data is deliberately fictional. NEVER store real CRM/HR PII in the
/// client demo store or SharedPreferences. Data lives only in AppState memory.
class DemoCrmGateway implements CrmGateway {
  final Set<int> disabledUserIds;
  DemoCrmGateway({this.disabledUserIds = const {}});
  late final List<CrmCustomer> _customers = [
    const CrmCustomer(id: 'C-001', name: '演示客户·星河', category: 'PERSON',
      business: '会员服务', memberTier: '金卡会员', memberExpiresAt: '2027-08-31',
      maskedContact: '***-****-1201', ownerName: '周知夏', remark: '关注活动体验与权益履约',
      ownerId: 8, departmentId: 3, teamId: 8, annualCardUsed: 2, annualCardLimit: 6,
      linkedMallMemberId: 'MALL-DEMO-101'),
    const CrmCustomer(id: 'C-002', name: '演示企业·云杉科技', category: 'COMPANY',
      business: '企业参访', memberTier: '企业客户', memberExpiresAt: '',
      maskedContact: '企业联系人信息已脱敏', ownerName: '苏以安',
      remark: '企业参访及沙龙合作', ownerId: 3, departmentId: 3),
    const CrmCustomer(id: 'C-003', name: '演示客户·知秋', category: 'PERSON',
      business: '演出活动', memberTier: '演出年卡', memberExpiresAt: '2027-06-30',
      maskedContact: '***-****-3102', ownerName: '林小满',
      remark: '年卡权益使用需逐次登记', ownerId: 12, departmentId: 3, teamId: 8,
      annualCardUsed: 3, annualCardLimit: 8,
      linkedTicketCardId: 'TICKET-DEMO-202'),
    const CrmCustomer(id: 'C-004', name: '演示客户·春屿', category: 'PERSON',
      business: '高端私宴', memberTier: '尊享会员', memberExpiresAt: '2027-10-31',
      maskedContact: '仅授权人员可见', ownerName: '许远山',
      remark: '高敏客户示例，不对普通员工开放', ownerId: 1,
      departmentId: 0, sensitive: true),
    const CrmCustomer(id: 'C-005', name: '演示企业·北辰咨询', category: 'COMPANY',
      business: '线下沙龙', memberTier: '企业客户', memberExpiresAt: '',
      maskedContact: '企业联系人信息已脱敏', ownerName: '唐予宁',
      remark: '开展跨行业交流活动', ownerId: 2, departmentId: 2),
  ];

  late final List<CrmBenefit> _benefits = [
    const CrmBenefit(id: 'B-01', customerId: 'C-001', title: '演出优先预约',
      total: 4, used: 1, serviceStatus: 'IN_PROGRESS'),
    const CrmBenefit(id: 'B-02', customerId: 'C-001', title: '专属活动席位',
      total: 2, used: 0, serviceStatus: 'PENDING'),
    const CrmBenefit(id: 'B-03', customerId: 'C-003', title: '年卡观演次数',
      total: 8, used: 3, serviceStatus: 'IN_PROGRESS'),
    const CrmBenefit(id: 'B-04', customerId: 'C-004', title: '私宴管家服务',
      total: 2, used: 1, serviceStatus: 'IN_PROGRESS'),
  ];

  late final List<CrmActivity> _activities = [
    const CrmActivity(id: 'A-01', customerId: 'C-001', kind: 'PERFORMANCE',
      title: '秋季音乐会观演服务', status: 'COMPLETED', date: '2026-10-18',
      ownerName: '周知夏', note: '入场服务已交付', participantIds: [8, 12]),
    const CrmActivity(id: 'A-02', customerId: 'C-001', kind: 'SERVICE',
      title: '会员年卡权益确认', status: 'IN_PROGRESS', date: '2026-11-28',
      ownerName: '林小满', note: '等待客户确认档期', participantIds: [12]),
    const CrmActivity(id: 'A-03', customerId: 'C-002', kind: 'VISIT',
      title: '企业创新参访', status: 'PLANNED', date: '2026-12-10',
      ownerName: '苏以安', note: '需确认现场协作人员', participantIds: [3, 8]),
    const CrmActivity(id: 'A-04', customerId: 'C-003', kind: 'PERFORMANCE',
      title: '演出年卡场次使用', status: 'COMPLETED', date: '2026-09-06',
      ownerName: '林小满', note: '已记录核销', participantIds: [12, 13]),
    const CrmActivity(id: 'A-05', customerId: 'C-004', kind: 'BANQUET',
      title: '高端私宴现场交付', status: 'PLANNED', date: '2027-01-08',
      ownerName: '许远山', note: '高敏演示数据', participantIds: [1]),
    const CrmActivity(id: 'A-07', customerId: 'C-001', kind: 'MALL',
      title: '商城会员订单归档', status: 'COMPLETED', date: '2026-11-10',
      ownerName: '周知夏', note: '商城订单系统关联示例（非实时同步）', participantIds: [8]),
    const CrmActivity(id: 'A-06', customerId: 'C-005', kind: 'SALON',
      title: '企业创新主题沙龙', status: 'IN_PROGRESS', date: '2026-12-04',
      ownerName: '唐予宁', note: '场地与讲师待确认', participantIds: [2, 21]),
  ];

  late final List<EmployeeArchive> _employees = [
    EmployeeArchive(id: 12, departmentId: 3, name: '林小满', department: '运营部',
      duty: '会员运营、活动服务', role: 'EMPLOYEE',
      accountStatus: disabledUserIds.contains(12) ? 'DISABLED' : 'ACTIVE',
      contractEnd: _dateAfter(18), contractArchiveStatus: 'ARCHIVED'),
    EmployeeArchive(id: 13, departmentId: 3, name: '陈星禾', department: '运营部',
      duty: '演出活动支持', role: 'EMPLOYEE', accountStatus: 'ACTIVE',
      contractEnd: _dateAfter(160), contractArchiveStatus: 'ARCHIVED'),
    EmployeeArchive(id: 8, departmentId: 3, name: '周知夏', department: '运营部',
      duty: '活动统筹、人员协调', role: 'TEAM_LEADER', accountStatus: 'ACTIVE',
      contractEnd: _dateAfter(9), contractArchiveStatus: 'MISSING'),
    EmployeeArchive(id: 3, departmentId: 3, name: '苏以安', department: '运营部',
      duty: '企业客户合作', role: 'DEPT_MANAGER', accountStatus: 'ACTIVE',
      contractEnd: _dateAfter(240), contractArchiveStatus: 'ARCHIVED'),
    const EmployeeArchive(id: 1, departmentId: 0, name: '许远山',
      department: '管理层', duty: '公司统筹', role: 'FOUNDER',
      accountStatus: 'ACTIVE', contractEnd: '', contractArchiveStatus: 'MISSING'),
    const EmployeeArchive(id: 21, departmentId: 2, name: '顾清禾',
      department: '产品部', duty: '产品与活动协作', role: 'EMPLOYEE',
      accountStatus: 'ACTIVE', contractEnd: '', contractArchiveStatus: 'MISSING'),
    EmployeeArchive(id: 2, departmentId: 2, name: '唐予宁', department: '产品部',
      duty: '产品与业务协同', role: 'DEPT_MANAGER', accountStatus: 'ACTIVE',
      contractEnd: _dateAfter(-6), contractArchiveStatus: 'ARCHIVED'),
    const EmployeeArchive(id: 14, departmentId: 3, name: '演示离职员工',
      department: '运营部', duty: '已离职，档案留存', role: 'EMPLOYEE',
      accountStatus: 'DISABLED', contractEnd: '2026-01-01',
      contractArchiveStatus: 'ARCHIVED'),
  ];

  static String _dateAfter(int days) {
    final dt = DateTime.now().add(Duration(days: days));
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  CrmAccess _access(UserProfile user) => CrmAccess.forUser(user);
  @override Future<CrmRevenueSummary> revenueSummary(UserProfile user) async {
    if (!_access(user).revenue) { throw const AppFailure('没有营收数据访问权限'); }
    final now = DateTime.now();
    return CrmRevenueSummary(
      month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      // Fictional demonstration amounts; never represent real company revenue.
      totalAmountFen: 12864000, orderCount: 42,
      byBusinessFen: const {
        '线上商城': 3280000, '演出活动': 5164000,
        '高端私宴': 2780000, '企业服务': 1640000,
      });
  }

  List<CrmCustomer> _visible(UserProfile user) {
    final access = _access(user);
    if (!access.customers) { throw const AppFailure('当前账号没有客户档案访问权限'); }
    return _customers.where((c) {
      if (c.sensitive && !access.sensitiveCustomers) { return false; }
      if (user.role == 'FOUNDER' || user.permissions.contains('CRM_ALL_READ')) { return true; }
      if (user.role == 'DEPT_MANAGER') { return c.departmentId == user.departmentId; }
      if (user.role == 'TEAM_LEADER') { return c.teamId != 0 && c.teamId == user.teamId; }
      // Operational staff can view only records assigned to themselves.
      return c.ownerId == user.id;
    }).toList();
  }
  CrmCustomer _authorizedCustomer(UserProfile user, String id) {
    for (final item in _visible(user)) {
      if (item.id == id) { return item; }
    }
    throw const AppFailure('无权查看此客户或客户不存在');
  }
  @override
  Future<CrmPage<CrmCustomer>> customers(UserProfile user, {
    String search = '', String category = '', String business = '',
    int page = 1, int size = 20}) async {
    final query = search.trim().toLowerCase();
    final list = _visible(user).where((c) =>
      (category.isEmpty || c.category == category) &&
      (business.isEmpty || c.business == business) &&
      (query.isEmpty || '${c.name} ${c.id} ${c.memberTier} ${c.business}'
        .toLowerCase().contains(query))).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    final start = ((page < 1 ? 1 : page) - 1) * size;
    if (start >= list.length) { return CrmPage(items: const [], total: list.length, hasMore: false); }
    final result = list.skip(start).take(size).toList();
    return CrmPage(items: result, total: list.length, hasMore: start + result.length < list.length);
  }
  @override
  Future<CrmCustomer> createCustomer(UserProfile user, {
    required String name, required String category, required String business,
    required String tier, String remark = ''}) async {
    if (!_access(user).editCustomers) { throw const AppFailure('没有新增客户的权限'); }
    if (name.trim().length < 2 || name.trim().length > 60) {
      throw const AppFailure('客户名称请填写 2–60 个字符');
    }
    final id = 'C-${(100 + _customers.length + 1)}';
    final item = CrmCustomer(id: id, name: name.trim(), category: category,
      business: business, memberTier: tier, memberExpiresAt: '',
      maskedContact: '未录入', ownerName: user.name, remark: remark.trim(),
      ownerId: user.id, departmentId: user.departmentId ?? 0,
      teamId: user.teamId ?? 0);
    _customers.add(item);
    return item;
  }
  @override Future<List<CrmBenefit>> benefits(UserProfile user, String customerId) async {
    _authorizedCustomer(user, customerId);
    return _benefits.where((e) => e.customerId == customerId).toList();
  }
  @override Future<CrmBenefit> consumeBenefit(UserProfile user, String benefitId) async {
    if (!_access(user).editCustomers) { throw const AppFailure('没有登记权益核销的权限'); }
    final idx = _benefits.indexWhere((b) => b.id == benefitId);
    if (idx < 0) { throw const AppFailure('权益不存在'); }
    final benefit = _benefits[idx];
    _authorizedCustomer(user, benefit.customerId);
    if (benefit.remaining <= 0) { throw const AppFailure('权益已用完，不能重复核销'); }
    final updated = benefit.useOne();
    _benefits[idx] = updated;
    // Annual-pass counters and entitlement consumption must stay consistent.
    if (benefit.title.contains('年卡')) {
      final cIndex = _customers.indexWhere((c) => c.id == benefit.customerId);
      if (cIndex >= 0) {
        final c = _customers[cIndex];
        _customers[cIndex] = CrmCustomer.fromJson({
          ...c.toJson(), 'annualCardUsed': c.annualCardUsed + 1,
        });
      }
    }
    return updated;
  }
  CrmActivity _withStaffNames(CrmActivity a) => CrmActivity(
    id: a.id, customerId: a.customerId, kind: a.kind, title: a.title,
    status: a.status, date: a.date, ownerName: a.ownerName, note: a.note,
    participantIds: a.participantIds,
    participantNames: a.participantIds.map((id) {
      for (final employee in _employees) {
        if (employee.id == id) { return employee.name; }
      }
      return '员工#$id';
    }).toList(),
  );
  @override Future<List<CrmActivity>> customerActivities(UserProfile user, String customerId) async {
    _authorizedCustomer(user, customerId);
    return _activities.where((e) => e.customerId == customerId)
      .map(_withStaffNames).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
  @override Future<CrmActivity> addActivity(UserProfile user, {
    required String customerId, required String kind, required String title,
    required String date, required String status,
    required List<int> participantIds, String note = ''}) async {
    if (!_access(user).editCustomers) { throw const AppFailure('没有新增业务记录的权限'); }
    _authorizedCustomer(user, customerId);
    if (title.trim().length < 2 || title.trim().length > 100 ||
        DateTime.tryParse(date) == null) {
      throw const AppFailure('请填写业务名称（2–100 字）及有效日期');
    }
    final record = CrmActivity(id: 'A-${100 + _activities.length + 1}',
      customerId: customerId, kind: kind, title: title.trim(), date: date,
      status: status, ownerName: user.name, note: note.trim(),
      participantIds: participantIds.toSet().toList());
    _activities.add(record);
    return record;
  }
  bool _employeeVisible(UserProfile user, EmployeeArchive e) {
    final access = _access(user);
    if (!access.employees) { return false; }
    if (user.role == 'FOUNDER' || user.role == 'HR_ADMIN' ||
        user.permissions.contains('HR_ALL_READ')) return true;
    return e.departmentId == user.departmentId;
  }
  @override Future<CrmPage<EmployeeArchive>> employees(UserProfile user, {
    String search = '', bool expiringOnly = false, int page = 1, int size = 20}) async {
    if (!_access(user).employees) { throw const AppFailure('没有人员档案访问权限'); }
    final query = search.trim().toLowerCase();
    final now = DateTime.now();
    final list = _employees.where((e) => _employeeVisible(user, e) &&
      (!expiringOnly || e.contractExpiring(now)) &&
      (query.isEmpty || '${e.name} ${e.department} ${e.duty}'
        .toLowerCase().contains(query))).toList();
    final start = ((page < 1 ? 1 : page) - 1) * size;
    if (start >= list.length) { return CrmPage(items: const [], total: list.length, hasMore: false); }
    final result = list.skip(start).take(size).toList();
    return CrmPage(items: result, total: list.length, hasMore: start + result.length < list.length);
  }
  @override Future<EmployeeArchive> createEmployee(UserProfile user, {
    required String name, required String department, required String duty,
    required String contractEnd}) async {
    if (!_access(user).editEmployees) { throw const AppFailure('没有新增员工档案的权限'); }
    if (name.trim().length < 2 || department.trim().isEmpty || duty.trim().isEmpty ||
        (contractEnd.isNotEmpty && DateTime.tryParse(contractEnd) == null)) {
      throw const AppFailure('请填写完整姓名、部门、岗位职责及正确的合同日期');
    }
    final next = _employees.map((e) => e.id).reduce((a,b) => a>b?a:b) + 1;
    final record = EmployeeArchive(id: next, departmentId: user.departmentId ?? 0,
      name: name.trim(), department: department.trim(), duty: duty.trim(),
      role: 'EMPLOYEE', accountStatus: 'ACTIVE', contractEnd: contractEnd,
      contractArchiveStatus: 'MISSING');
    _employees.add(record);
    return record;
  }
  @override Future<List<CrmActivity>> employeeActivities(UserProfile user, int employeeId) async {
    final exists = _employees.any((e) => e.id == employeeId && _employeeVisible(user, e));
    if (!exists) { throw const AppFailure('无权查看该员工的业务参与记录'); }
    final accessibleCustomers = _access(user).customers
      ? _visible(user).map((e) => e.id).toSet() : <String>{};
    return _activities.where((a) => a.participantIds.contains(employeeId) &&
        accessibleCustomers.contains(a.customerId)).map(_withStaffNames).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

/// Proposed V2 endpoints. They are NOT implemented in the existing backend.
/// Errors are surfaced; production mode never falls back to demo records.
class ApiCrmGateway implements CrmGateway {
  final String baseUrl;
  final http.Client client;
  final FlutterSecureStorage store;
  ApiCrmGateway({required this.baseUrl, http.Client? client,
    FlutterSecureStorage? store}): client = client ?? http.Client(),
    store = store ?? const FlutterSecureStorage();

  Future<dynamic> _request(String method, String path, {
    Map<String, String>? query, Object? data}) async {
    final token = await store.read(key: 'pandora_access_token');
    if (token == null || token.isEmpty) { throw const AppFailure('登录已失效，请重新登录'); }
    final url = '${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path';
    final uri = Uri.parse(url).replace(queryParameters: query);
    final headers = <String, String>{
      'Authorization': 'Bearer $token', 'Content-Type': 'application/json; charset=utf-8'};
    try {
      late http.Response response;
      switch (method) {
        case 'POST':
          response = await client.post(uri, headers: headers,
            body: jsonEncode(data)).timeout(const Duration(seconds: 15));
          break;
        default:
          response = await client.get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      }
      if (response.statusCode == 401) { throw const AppFailure('登录已失效，请重新登录'); }
      if (response.statusCode == 403) { throw const AppFailure('服务器拒绝访问：没有对应数据权限'); }
      if (response.statusCode == 404) { throw const AppFailure('二期接口尚未部署，请联系后端联调'); }
      final envelope = mapOf(jsonDecode(utf8.decode(response.bodyBytes)));
      if (response.statusCode < 200 || response.statusCode >= 300 ||
          intOf(envelope['code'], -1) != 0) {
        throw AppFailure(textOf(envelope['message'], '请求失败（HTTP ${response.statusCode}）'));
      }
      return envelope['data'];
    } on AppFailure { rethrow; }
      on TimeoutException { throw const AppFailure('CRM 请求超时，请检查网络'); }
      on FormatException { throw const AppFailure('CRM 接口响应格式不正确'); }
      on http.ClientException { throw const AppFailure('无法连接 CRM 服务'); }
  }
  @override Future<CrmRevenueSummary> revenueSummary(UserProfile user) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final result = await _request('GET', '/crm/revenue/summary',
      query: {'month': month});
    if (mapOf(result)['totalAmountFen'] == null) {
      throw const AppFailure('营收汇总接口没有返回金额，拒绝显示伪造的 0');
    }
    return CrmRevenueSummary.fromJson(result);
  }
  CrmPage<T> _page<T>(dynamic raw, T Function(dynamic) convert, int page, int size) {
    if (raw == null) { throw const AppFailure('CRM 接口未返回 data，不确认有记录'); }
    final m = mapOf(raw);
    final records = raw is List ? raw : listOf(m['items']);
    final total = intOf(m['total'], records.length);
    // A legacy plain array is a single page; do not fetch it forever.
    final more = raw is List ? false : page * size < total;
    return CrmPage(items: records.map(convert).toList(), total: total, hasMore: more);
  }
  @override Future<CrmPage<CrmCustomer>> customers(UserProfile user, {
    String search = '', String category = '', String business = '',
    int page = 1, int size = 20}) async {
    final data = await _request('GET', '/crm/customers', query: {
      'page': '$page', 'size': '$size',
      if (search.isNotEmpty) 'keyword': search,
      if (category.isNotEmpty) 'category': category,
      if (business.isNotEmpty) 'business': business,
    });
    return _page(data, CrmCustomer.fromJson, page, size);
  }
  @override Future<CrmCustomer> createCustomer(UserProfile user, {
    required String name, required String category, required String business,
    required String tier, String remark = ''}) async {
    final result = await _request('POST', '/crm/customers', data: {
      'name': name, 'category': category, 'business': business,
      'memberTier': tier, 'remark': remark});
    if (mapOf(result)['id'] == null) { throw const AppFailure('服务器未返回已创建的客户，不确认保存成功'); }
    return CrmCustomer.fromJson(result);
  }
  @override Future<List<CrmBenefit>> benefits(UserProfile user, String customerId) async {
    final result = await _request('GET', '/crm/customers/${Uri.encodeComponent(customerId)}/benefits');
    if (result == null) { throw const AppFailure('服务器未返回权益列表'); }
    return (result is List ? result : listOf(mapOf(result)['items']))
      .map(CrmBenefit.fromJson).toList();
  }
  @override Future<CrmBenefit> consumeBenefit(UserProfile user, String benefitId) async {
    final result = await _request('POST', '/crm/benefits/${Uri.encodeComponent(benefitId)}/redeem', data: {});
    if (mapOf(result)['id'] == null) { throw const AppFailure('服务器未返回核销结果，不确认成功'); }
    return CrmBenefit.fromJson(result);
  }
  @override Future<List<CrmActivity>> customerActivities(UserProfile user, String customerId) async {
    final result = await _request('GET', '/crm/customers/${Uri.encodeComponent(customerId)}/activities');
    if (result == null) { throw const AppFailure('服务器未返回客户业务记录'); }
    return (result is List ? result : listOf(mapOf(result)['items']))
      .map(CrmActivity.fromJson).toList();
  }
  @override Future<CrmActivity> addActivity(UserProfile user, {
    required String customerId, required String kind, required String title,
    required String date, required String status,
    required List<int> participantIds, String note = ''}) async {
    final result = await _request('POST', '/crm/activities', data: {
      'customerId': customerId, 'kind': kind, 'title': title,
      'date': date, 'status': status, 'participantIds': participantIds,
      'note': note});
    if (mapOf(result)['id'] == null) { throw const AppFailure('服务器未返回业务记录，不确认保存成功'); }
    return CrmActivity.fromJson(result);
  }
  @override Future<CrmPage<EmployeeArchive>> employees(UserProfile user, {
    String search = '', bool expiringOnly = false, int page = 1, int size = 20}) async {
    final data = await _request('GET', '/hr/employees', query: {
      'page': '$page', 'size': '$size', 'keyword': search,
      if (expiringOnly) 'contractExpiringDays': '30',
    });
    return _page(data, EmployeeArchive.fromJson, page, size);
  }
  @override Future<EmployeeArchive> createEmployee(UserProfile user, {
    required String name, required String department, required String duty,
    required String contractEnd}) async {
    final result = await _request('POST', '/hr/employees', data: {
      'name': name, 'department': department, 'duty': duty,
      'contractEnd': contractEnd.isEmpty ? null : contractEnd});
    if (mapOf(result)['id'] == null) { throw const AppFailure('服务器未返回已创建的员工档案'); }
    return EmployeeArchive.fromJson(result);
  }
  @override Future<List<CrmActivity>> employeeActivities(UserProfile user, int employeeId) async {
    final result = await _request('GET', '/hr/employees/$employeeId/activities');
    if (result == null) { throw const AppFailure('服务器未返回员工业务记录'); }
    return (result is List ? result : listOf(mapOf(result)['items']))
      .map(CrmActivity.fromJson).toList();
  }
}
