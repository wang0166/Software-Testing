import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'dispatch_page.dart';

/// 任务清单只保留「收到的任务」和「派发任务」。
class TasksPage extends StatefulWidget {
  final AppState app;
  const TasksPage({super.key, required this.app});
  @override State<TasksPage> createState() => _TasksPageState();
}
class _TasksPageState extends State<TasksPage> {
  int mode = 0;
  late Future<List<TaskItem>> inbox;
  late Future<List<DispatchedTask>> sent;
  bool get canDispatch => const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER'].contains(widget.app.user!.role);
  @override void initState() {super.initState(); _refresh();}
  void _refresh() {inbox = widget.app.repo.tasks(personal: false); if (canDispatch) sent = widget.app.repo.dispatchedTasks();}
  Future<void> _advance(TaskItem task) async {
    final options = task.status == 'NOT_STARTED' ? const ['IN_PROGRESS'] : task.status == 'IN_PROGRESS' ? const ['COMPLETED'] : const <String>[];
    if (options.isEmpty) {toast(context, '当前任务无需变更进度'); return;}
    try {await widget.app.repo.updateTask(task, options.first); if (mounted) {toast(context, '任务进度已保存'); setState(_refresh);}}
    catch (e) {if (mounted) toast(context, '$e');}
  }
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('任务清单', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Palette.deep)),
      const SizedBox(height: 4), const Text('接收任务与派发任务分开管理', style: TextStyle(color: Palette.muted, fontSize: 12)),
      const SizedBox(height: 14), Row(children: [
        Expanded(child: _tab('收到的任务', 0)), const SizedBox(width: 10), Expanded(child: _tab('派发任务', 1)),
      ]),
    ])),
    Expanded(child: mode == 0 ? _received() : _dispatched()),
  ]);
  Widget _tab(String text, int value) => InkWell(onTap: () => setState(() => mode = value), borderRadius: BorderRadius.circular(15), child: Container(
    alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: mode == value ? Palette.deep : Colors.white, borderRadius: BorderRadius.circular(15)),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: mode == value ? Colors.white : Palette.muted))));
  Widget _received() => FutureBuilder<List<TaskItem>>(future: inbox, builder: (context, s) {
    if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (s.hasError) return ErrorPanel(error: s.error!, onRetry: () => setState(_refresh));
    final items = s.data ?? [];
    if (items.isEmpty) return const EmptyPanel(title: '暂无收到的任务', subtitle: '直属上级派发任务后会出现在这里');
    final done = items.where((i) => i.status == 'COMPLETED').length;
    return RefreshIndicator(onRefresh: () async {setState(_refresh); await inbox;}, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 35), children: [
      _summary('收到 ${items.length} 项任务', '已完成 $done 项', items.isEmpty ? 0 : done / items.length),
      const SizedBox(height: 13),
      ...items.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(20), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 17),
        leading: const CircleAvatar(backgroundColor: Palette.sage, child: Icon(Icons.assignment_outlined, color: Palette.primary)),
        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.deep)),
        subtitle: Text('${t.details.isEmpty ? '暂无描述' : t.details}\n截止：${t.deadline ?? '未设置'}', maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: Palette.muted), onTap: () => _detail(t),
      )))),
    ]));
  });
  Widget _dispatched() {
    if (!canDispatch) return const EmptyPanel(title: '暂无派发权限', subtitle: '员工可查看收到的任务；直属上级可派发任务。', icon: Icons.lock_outline_rounded);
    return FutureBuilder<List<DispatchedTask>>(future: sent, builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return ErrorPanel(error: s.error!, onRetry: () => setState(_refresh));
      final items = s.data ?? [];
      return RefreshIndicator(onRefresh: () async {setState(_refresh); await sent;}, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
        FilledButton.icon(onPressed: () async {await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DispatchPage(app: widget.app))); if (mounted) setState(_refresh);}, icon: const Icon(Icons.add_task_rounded), label: const Text('派发新任务 / 管理检查')),
        const SizedBox(height: 14),
        if (items.isEmpty) const EmptyPanel(title: '还没有派发任务', subtitle: '点击上方按钮为直属下级派发任务')
        else ...items.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: ListTile(
          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.deep)),
          subtitle: Text('截止 ${t.deadline}\n接收 ${t.assigneeCount} 人 · 完成 ${t.completedCount} 人'), isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded), onTap: () async {await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DispatchPage(app: widget.app))); if (mounted) setState(_refresh);},
        )))),
      ]));
    });
  }
  Widget _summary(String title, String subtitle, double progress) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
    const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFFB7DCD7), fontSize: 12)),
    const SizedBox(height: 12), LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white24, color: Palette.gold),
  ]));
  void _detail(TaskItem t) => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(t.name, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 10), Text(t.details), const SizedBox(height: 15), Text('开始：${t.startDate ?? '未设置'}\n截止：${t.deadline ?? '未设置'}'),
    const SizedBox(height: 12), StatusBadge(status: t.status),
    const SizedBox(height: 16), if (t.status != 'COMPLETED') FilledButton(onPressed: () {Navigator.pop(ctx); _advance(t);}, child: Text(t.status == 'NOT_STARTED' ? '开始任务' : '标记完成')),
    if (t.status == 'COMPLETED' && (t.reviewStatus == 'NONE' || t.reviewStatus == 'RETURNED')) FilledButton(onPressed: () async {Navigator.pop(ctx); try {await widget.app.repo.inviteReview(t.id); if (mounted) {toast(context, '已邀请直属上级检查'); setState(_refresh);}} catch (e) {if (mounted) toast(context, '$e');}}, child: const Text('邀请上级检查')),
  ]))));
}
