import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import 'log_detail_page.dart';

/// 只展示后端授权返回的下属业务信息，绝不推测联系方式或展示私密点评。
class SubordinateDetailPage extends StatefulWidget {
  final AppState app;
  final SubordinateTaskSummary member;
  const SubordinateDetailPage({super.key, required this.app,
    required this.member});

  @override State<SubordinateDetailPage> createState() => _SubordinateDetailPageState();
}

class _SubordinateDetailPageState extends State<SubordinateDetailPage> {
  late Future<List<WorkLog>> _logs;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    _logs = widget.app.repo.logs().then((items) =>
      items.where((e) => e.authorId == widget.member.userId).toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate)));
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return Scaffold(
      appBar: AppBar(title: const Text('下属个人信息')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          BusinessPanel(
            title: '成员信息',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 28, backgroundColor: Palette.sage,
                  child: Text(member.name.isEmpty ? '员' : member.name.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 22, color: Palette.deep)),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: const TextStyle(color: Palette.deep,
                      fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    _field('部门 / 组织', member.departmentName),
                    if (member.teamName.isNotEmpty)
                      _field('团队', member.teamName),
                    if (member.role.isNotEmpty)
                      _field('岗位角色', const {
                        'EMPLOYEE': '员工', 'TEAM_LEADER': '团队长',
                        'DEPT_MANAGER': '部门老总', 'FOUNDER': '创始人',
                      }[member.role] ?? member.role),
                    if (member.username.isNotEmpty)
                      _field('工作账号', member.username),
                    _field('MBTI（选填）', member.mbtiType.isEmpty ? '未提供' : member.mbtiType),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          BusinessPanel(
            title: '当前任务', count: null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: _metric('任务总数', member.total)),
                  Expanded(child: _metric('进行中', member.inProgress)),
                  Expanded(child: _metric('已完成', member.completed)),
                ]),
                const SizedBox(height: 12),
                if (member.tasks.isEmpty)
                  const BusinessEmpty('当前没有可查看的任务')
                else
                  for (var i = 0; i < member.tasks.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Palette.divider),
                    BusinessRow(index: i + 1, title: member.tasks[i].name,
                      subtitle: '${taskTypeLabel(member.tasks[i].taskType)} · ${member.tasks[i].statusLabel} · 截止 ${member.tasks[i].deadline ?? '未设置'}'),
                  ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          BusinessPanel(
            title: '工作日志',
            child: FutureBuilder<List<WorkLog>>(
              future: _logs,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('日志暂不可用：${snapshot.error}',
                      style: const TextStyle(color: Palette.muted, fontSize: 12)),
                  );
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) return const BusinessEmpty('暂无该成员授权范围内的日志');
                return Column(children: [
                  for (var i = 0; i < logs.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Palette.divider),
                    BusinessRow(
                      title: logs[i].content.replaceAll('\n', ' '),
                      subtitle: '${logs[i].logDate} · ${logs[i].submitted ? '已提交' : '草稿'}',
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => LogDetailPage(app: widget.app, log: logs[i]),
                      )),
                    ),
                  ],
                ]);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text('仅展示当前账号获得授权的人员、任务与日志。个人联系方式等字段须由后端明确授权后才可展示。',
              style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text('$label：$value', style: const TextStyle(
      color: Palette.muted, fontSize: 12, height: 1.4)),
  );

  Widget _metric(String label, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$count', style: const TextStyle(color: Palette.deep,
        fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Palette.muted, fontSize: 11)),
    ],
  );
}
