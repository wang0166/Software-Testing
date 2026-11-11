import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/log_filters.dart';
import 'package:mobile/core/models.dart';

void main() {
  const logs = <WorkLog>[
    WorkLog(id: 1, authorId: 100, authorName: '主管', logDate: '2026-10-29',
      content: '管理日报', status: 'SUBMITTED', departmentName: '研发部'),
    WorkLog(id: 2, authorId: 101, authorName: '直属下属', logDate: '2026-10-29',
      content: '任务开发', status: 'SUBMITTED', departmentName: '研发部'),
    WorkLog(id: 3, authorId: 102, authorName: '同部门同事', logDate: '2026-10-29',
      content: '单元测试', status: 'SUBMITTED', departmentName: '研发部'),
    WorkLog(id: 4, authorId: 201, authorName: '另一部门员工', logDate: '2026-10-29',
      content: '市场推广', status: 'SUBMITTED', departmentName: '市场部'),
  ];

  test('我的下属独立筛选，不把同部门人员误判为下属', () {
    final result = filterWorkLogs(authorized: logs, viewerId: 100,
      mode: '我的下属', subordinateIds: {101});
    expect(result.map((e) => e.authorId), [101]);
  });

  test('我的下属可以再次按个人筛选，且不能越过授权名单', () {
    final result = filterWorkLogs(authorized: logs, viewerId: 100,
      mode: '我的下属', subordinateIds: {101, 201}, selectedSubordinateId: 102);
    expect(result, isEmpty);
  });

  test('部门日志筛选独立于我的下属筛选', () {
    final result = filterWorkLogs(authorized: logs, viewerId: 100,
      mode: '部门日志', selectedDepartment: '研发部');
    expect(result.map((e) => e.id), [1, 2, 3]);
  });

  test('新的下属组织字段能够向后兼容旧接口', () {
    final old = SubordinateTaskSummary.fromJson({
      'userId': 101, 'name': '员工', 'departmentName': '研发部', 'tasks': [],
    });
    expect(old.role, '');
    final newer = SubordinateTaskSummary.fromJson({
      'userId': 101, 'name': '员工', 'departmentName': '研发部',
      'role': 'EMPLOYEE', 'teamName': '移动端组', 'username': 'u101', 'tasks': [],
    });
    expect(newer.teamName, '移动端组');
    expect(newer.username, 'u101');
  });
}
