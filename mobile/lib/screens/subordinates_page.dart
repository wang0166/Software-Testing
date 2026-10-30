import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import 'subordinate_detail_page.dart';

/// Management perspective: tasks assigned to subordinates by anyone,
/// not merely tasks sent by the current viewer.
class SubordinatesPage extends StatefulWidget {
  final AppState app;
  const SubordinatesPage({super.key, required this.app});
  @override State<SubordinatesPage> createState() => _SubordinatesPageState();
}
class _SubordinatesPageState extends State<SubordinatesPage> {
  late Future<List<SubordinateTaskSummary>> _future;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() {
    _future = widget.app.repo.subordinatesTaskOverview();
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<SubordinateTaskSummary>>(future: _future, builder: (context, snap) => RefreshIndicator(
    onRefresh: () async { setState(_refresh); await _future; },
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 110), children: [
      const BusinessHeading(title: '下属工作动态', subtitle: '查看权限内成员的全部在办任务，包括其他人派发的任务'),
      const SizedBox(height: 15),
      if (snap.connectionState != ConnectionState.done) const Center(child: Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator()))
      else if (snap.hasError) BusinessPanel(title: '任务汇总暂不可用', child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('需要后端提供 /tasks/subordinates/overview 接口，并按组织权限过滤。', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 8), Text('${snap.error}', style: const TextStyle(color: Palette.coral, fontSize: 11)),
        TextButton(onPressed: () => setState(_refresh), child: const Text('重试')),
      ])))
      else if ((snap.data ?? []).isEmpty) const BusinessPanel(title: '下属任务', child: BusinessEmpty('当前账号暂无可管理的下属任务'))
      else ...[
        for (final member in snap.data!) Padding(padding: const EdgeInsets.only(bottom: 11), child: BusinessPanel(
          title: member.name, kicker: member.departmentName,
          child: Column(children: [
            Padding(padding: const EdgeInsets.only(top: 11), child: Row(children: [
              Semantics(
                button: true,
                label: '查看${member.name}的个人信息',
                child: InkWell(
                  key: ValueKey('subordinate_avatar_${member.userId}'),
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => SubordinateDetailPage(app: widget.app, member: member))),
                  child: CircleAvatar(
                    backgroundColor: Palette.sage,
                    radius: 22,
                    child: Text(member.name.isEmpty ? '员' : member.name.substring(0, 1),
                      style: const TextStyle(color: Palette.deep, fontSize: 17,
                        fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(member.name, style: const TextStyle(color: Palette.deep,
                  fontWeight: FontWeight.w800, fontSize: 14)),
                const Text('点击头像查看个人信息、全部任务及日志',
                  style: TextStyle(color: Palette.muted, fontSize: 11)),
              ])),
              const Icon(Icons.chevron_right, color: Palette.muted, size: 17),
            ])),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
              Text('${member.total} 项任务', style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12), Text('进行中 ${member.inProgress}', style: const TextStyle(color: Palette.primary, fontSize: 11)),
              const Spacer(), Text('已完成 ${member.completed}', style: const TextStyle(color: Palette.muted, fontSize: 11)),
            ])),
            for (final task in member.tasks.take(3)) ...[
              const Divider(height: 1, color: Palette.divider),
              BusinessRow(title: task.name, subtitle: '${taskTypeLabel(task.taskType)} · ${task.statusLabel} · 截止 ${task.deadline ?? '未设置'}'),
            ],
            if (member.tasks.length > 3)
              Align(alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => SubordinateDetailPage(app: widget.app, member: member))),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('查看全部 ${member.tasks.length} 项任务',
                      style: const TextStyle(color: Palette.primary,
                        fontWeight: FontWeight.w800, fontSize: 12,
                        decoration: TextDecoration.underline))),
                )),
          ]),
        )),
      ],
    ]),
  ));
}
