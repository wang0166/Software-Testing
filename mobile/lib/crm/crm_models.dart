import '../core/models.dart';

/// Front-end affordances only. API permission/scope checks MUST be server-side.
class CrmAccess {
  final bool customers, editCustomers, sensitiveCustomers, revenue;
  final bool employees, contractAlerts, contracts, editEmployees;
  const CrmAccess({this.customers = false, this.editCustomers = false,
    this.sensitiveCustomers = false, this.revenue = false,
    this.employees = false, this.contractAlerts = false, this.contracts = false,
    this.editEmployees = false});

  factory CrmAccess.forUser(UserProfile? user) {
    if (user == null || !user.isActive) { return const CrmAccess(); }
    final role = user.role.toUpperCase();
    // These are UI visibility hints, not authorization decisions.
    final founder = role == 'FOUNDER';
    final manager = role == 'DEPT_MANAGER';
    final lead = role == 'TEAM_LEADER';
    final staff = role == 'EMPLOYEE';
    final operations = role == 'OPERATIONS_PARTNER';
    final finance = role == 'FINANCE';
    final hr = role == 'HR_ADMIN';
    final p = user.permissions.toSet();
    final canRead = founder || manager || lead || staff || operations || finance ||
        p.contains('CRM_READ');
    return CrmAccess(
      customers: canRead,
      editCustomers: founder || manager || operations || p.contains('CRM_WRITE'),
      sensitiveCustomers: founder || p.contains('CRM_SENSITIVE_READ'),
      revenue: founder || finance || p.contains('CRM_REVENUE_READ'),
      employees: founder || manager || hr || p.contains('HR_READ'),
      contractAlerts: founder || manager || hr || p.contains('HR_CONTRACT_ALERT_READ'),
      contracts: founder || hr || p.contains('HR_CONTRACT_READ'),
      editEmployees: founder || hr || p.contains('HR_WRITE'),
    );
  }
}

class CrmPage<T> {
  final List<T> items;
  final int total;
  final bool hasMore;
  const CrmPage({required this.items, required this.total, required this.hasMore});
}

class CrmCustomer {
  final String id, name, category, business, memberTier, memberExpiresAt;
  final String maskedContact, ownerName, remark, linkedMallMemberId, linkedTicketCardId;
  final int ownerId, departmentId, teamId, annualCardUsed, annualCardLimit;
  final bool sensitive;
  const CrmCustomer({required this.id, required this.name, required this.category,
    required this.business, required this.memberTier, required this.memberExpiresAt,
    required this.maskedContact, required this.ownerName, required this.remark,
    this.linkedMallMemberId = '', this.linkedTicketCardId = '',
    required this.ownerId, required this.departmentId, this.teamId = 0,
    this.annualCardUsed = 0, this.annualCardLimit = 0, this.sensitive = false});
  factory CrmCustomer.fromJson(dynamic raw) {
    final j = mapOf(raw);
    return CrmCustomer(
      id: textOf(j['id']), name: textOf(j['name']),
      category: textOf(j['category'], 'PERSON'),
      business: textOf(j['business'], '会员服务'),
      memberTier: textOf(j['memberTier'], '普通客户'),
      memberExpiresAt: textOf(j['memberExpiresAt']),
      maskedContact: textOf(j['maskedContact']),
      linkedMallMemberId: textOf(j['linkedMallMemberId']),
      linkedTicketCardId: textOf(j['linkedTicketCardId']),
      ownerName: textOf(j['ownerName']), remark: textOf(j['remark']),
      ownerId: intOf(j['ownerId']), departmentId: intOf(j['departmentId']),
      teamId: intOf(j['teamId']),
      annualCardUsed: intOf(j['annualCardUsed']),
      annualCardLimit: intOf(j['annualCardLimit']),
      sensitive: j['sensitive'] == true,
    );
  }
  bool get isCompany => category == 'COMPANY';
  int get annualCardRemaining => (annualCardLimit - annualCardUsed).clamp(0, 999999).toInt();
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'category': category, 'business': business,
    'memberTier': memberTier, 'memberExpiresAt': memberExpiresAt,
    'maskedContact': maskedContact, 'ownerName': ownerName, 'remark': remark,
    'linkedMallMemberId': linkedMallMemberId,
    'linkedTicketCardId': linkedTicketCardId,
    'ownerId': ownerId, 'departmentId': departmentId, 'teamId': teamId,
    'annualCardUsed': annualCardUsed, 'annualCardLimit': annualCardLimit,
    'sensitive': sensitive,
  };
}

class CrmBenefit {
  final String id, customerId, title, serviceStatus;
  final int total, used;
  const CrmBenefit({required this.id, required this.customerId,
    required this.title, required this.total, required this.used,
    required this.serviceStatus});
  factory CrmBenefit.fromJson(dynamic raw) {
    final j = mapOf(raw);
    return CrmBenefit(id: textOf(j['id']), customerId: textOf(j['customerId']),
      title: textOf(j['title']), total: intOf(j['total']),
      used: intOf(j['used']), serviceStatus: textOf(j['serviceStatus'], 'PENDING'));
  }
  int get remaining => (total - used).clamp(0, 999999).toInt();
  CrmBenefit useOne() => CrmBenefit(id: id, customerId: customerId, title: title,
    total: total, used: used + 1,
    serviceStatus: used + 1 >= total ? 'COMPLETED' : 'IN_PROGRESS');
}

class CrmActivity {
  final String id, customerId, kind, title, status, date, ownerName, note;
  final List<int> participantIds;
  final List<String> participantNames;
  const CrmActivity({required this.id, required this.customerId,
    required this.kind, required this.title, required this.status,
    required this.date, required this.ownerName, required this.note,
    this.participantIds = const [], this.participantNames = const []});
  factory CrmActivity.fromJson(dynamic raw) {
    final j = mapOf(raw);
    return CrmActivity(id: textOf(j['id']), customerId: textOf(j['customerId']),
      kind: textOf(j['kind'], 'OTHER'), title: textOf(j['title']),
      status: textOf(j['status'], 'PLANNED'), date: textOf(j['date']),
      ownerName: textOf(j['ownerName']), note: textOf(j['note']),
      participantIds: listOf(j['participantIds']).map((e) => intOf(e)).toList(),
      participantNames: listOf(j['participantNames']).map((e) => textOf(e)).toList());
  }
}

class EmployeeArchive {
  final int id, departmentId;
  final String name, department, duty, role, accountStatus;
  final String contractEnd, contractArchiveStatus;
  const EmployeeArchive({required this.id, required this.departmentId,
    required this.name, required this.department, required this.duty,
    required this.role, required this.accountStatus,
    required this.contractEnd, required this.contractArchiveStatus});
  factory EmployeeArchive.fromJson(dynamic raw) {
    final j = mapOf(raw);
    return EmployeeArchive(id: intOf(j['id']), departmentId: intOf(j['departmentId']),
      name: textOf(j['name']), department: textOf(j['department']),
      duty: textOf(j['duty']), role: textOf(j['role']),
      accountStatus: textOf(j['accountStatus'], 'ACTIVE'),
      contractEnd: textOf(j['contractEnd']),
      contractArchiveStatus: textOf(j['contractArchiveStatus'], 'MISSING'));
  }
  bool get active => accountStatus.toUpperCase() == 'ACTIVE';
  int? daysToContractEnd(DateTime now) {
    if (contractEnd.isEmpty) { return null; }
    final end = DateTime.tryParse(contractEnd);
    if (end == null) { return null; }
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(end.year, end.month, end.day).difference(today).inDays;
  }
  bool contractExpiring(DateTime now, {int within = 30}) {
    final days = daysToContractEnd(now);
    return active && days != null && days >= 0 && days <= within;
  }
}

String crmStatusLabel(String status) => const {
  'PENDING': '待处理', 'IN_PROGRESS': '进行中', 'COMPLETED': '已完成',
  'PLANNED': '待开展', 'CANCELLED': '已取消',
}[status] ?? status;

String crmActivityKindLabel(String kind) => const {
  'MALL': '商城订单', 'PERFORMANCE': '演出活动', 'BANQUET': '高端私宴',
  'VISIT': '企业参访', 'SALON': '线下沙龙', 'SERVICE': '会员服务',
}[kind] ?? '其他业务';

/// Money uses integer cents (fen) to avoid floating point accounting errors.
class CrmRevenueSummary {
  final String month;
  final int totalAmountFen, orderCount;
  final Map<String, int> byBusinessFen;
  const CrmRevenueSummary({required this.month, required this.totalAmountFen,
    required this.orderCount, required this.byBusinessFen});
  factory CrmRevenueSummary.fromJson(dynamic raw) {
    final j = mapOf(raw);
    final source = mapOf(j['byBusinessFen']);
    return CrmRevenueSummary(
      month: textOf(j['month']), totalAmountFen: intOf(j['totalAmountFen']),
      orderCount: intOf(j['orderCount']),
      byBusinessFen: source.map((k, v) => MapEntry(k, intOf(v))));
  }
  static String amountLabel(int fen) {
    final positive = fen.abs();
    return '${fen < 0 ? '-' : ''}¥${positive ~/ 100}.${(positive % 100).toString().padLeft(2, '0')}';
  }
}
