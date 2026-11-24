import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Reusable inbox in the task ledger and in a disabled employee's history card.
/// All records/candidates are provided by the repository; permissions and
/// confirmation must be checked independently by the Spring Boot backend.
class TaskHandoverInbox extends StatefulWidget {
  final AppState app;
  final int? formerUserId;
  /// null shows both status chips; true/false locks to a single status.
  final bool? historyOnly;
  final VoidCallback? onChanged;
  const TaskHandoverInbox({super.key, required this.app,
    this.formerUserId, this.historyOnly, this.onChanged});

  @override State<TaskHandoverInbox> createState() => _TaskHandoverInboxState();
}

class _TaskHandoverInboxState extends State<TaskHandoverInbox> {
  late Future<List<TaskHandover>> _future;
  bool _history = false;

  @override void initState() {
    super.initState();
    _history = widget.historyOnly ?? false;
    _load();
  }
  void _load() => _future = widget.app.repo.taskHandovers();
  Future<void> _refresh() async {
    setState(_load);
    try { await _future; } catch (_) { /* Shown below. */ }
  }

  Future<void> _open(TaskHandover item) async {
    if (!item.pending) return;
    final success = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => TaskHandoverDetailPage(
        app: widget.app, handover: item)));
    if (success == true && mounted) {
      await _refresh();
      widget.onChanged?.call();
    }
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<TaskHandover>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Padding(padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, color: Palette.coral),
            const SizedBox(height: 8),
            const Text('交接服务暂不可用；不会在本地假装完成交接'),
            Text('${snapshot.error}', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Palette.muted)),
            TextButton(onPressed: _refresh, child: const Text('重试')),
          ])));
      }
      final all = (snapshot.data ?? []).where((h) => widget.formerUserId == null ||
        h.originalUserId == widget.formerUserId).toList();
      final pending = all.where((h) => h.pending).toList();
      final showingHistory = widget.historyOnly ?? _history;
      final shown = all.where((h) => showingHistory ? !h.pending : h.pending).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.historyOnly == null) ...[
                ChoiceChip(label: Text('待交接 ${pending.length}'),
                  key: const Key('handover_pending_tab'), selected: !_history,
                  onSelected: (_) => setState(() => _history = false)),
                ChoiceChip(label: Text('已交接 ${all.length - pending.length}'),
                  key: const Key('handover_completed_tab'), selected: _history,
                  onSelected: (_) => setState(() => _history = true)),
              ] else
                Text('共 ${shown.length} 项', style: const TextStyle(
                  color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新')),
            ])),
        Expanded(child: shown.isEmpty
          ? Center(child: Text(showingHistory ? '没有已交接的任务' : '暂无待交接任务',
            style: const TextStyle(color: Palette.muted)))
          : ListView.separated(
            key: const Key('task_handover_list'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 30),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final h = shown[index];
              return Material(
                color: h.pending ? const Color(0xFFFFFAEE) : const Color(0xFFF1F4F3),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('handover_${h.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: h.pending ? () => _open(h) : null,
                  child: Padding(padding: const EdgeInsets.all(13),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(h.taskName, maxLines: 2,
                          style: const TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 14, color: Palette.deep))),
                        Text(h.pending ? '待交接' : '已交接', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11,
                          color: h.pending ? const Color(0xFF9A6322) : const Color(0xFF38836C))),
                      ]),
                      const SizedBox(height: 4),
                      Text('原负责人：${h.originalUserName}（账号已停用）',
                        style: const TextStyle(color: Palette.muted, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text('原进度 ${h.progressPercent}% · ${h.deadline ?? '未设置截止日期'}',
                        style: const TextStyle(color: Palette.muted, fontSize: 11)),
                      if (!h.pending) Text('新负责人：${h.newAssigneeName ?? '—'} · 历史记录保留',
                        style: const TextStyle(color: Palette.muted, fontSize: 11)),
                      if (h.pending) const Align(alignment: Alignment.centerRight,
                        child: Text('办理交接 ›', style: TextStyle(color: Palette.primary,
                          fontWeight: FontWeight.w800, fontSize: 12))),
                    ])),
                ));
            })),
      ]);
    },
  );
}

class TaskHandoverInboxPage extends StatelessWidget {
  final AppState app;
  final int? formerUserId;
  const TaskHandoverInboxPage({super.key, required this.app, this.formerUserId});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('任务交接')),
    body: TaskHandoverInbox(app: app, formerUserId: formerUserId));
}

class TaskHandoverDetailPage extends StatefulWidget {
  final AppState app;
  final TaskHandover handover;
  const TaskHandoverDetailPage({super.key, required this.app, required this.handover});
  @override State<TaskHandoverDetailPage> createState() => _TaskHandoverDetailPageState();
}

class _TaskHandoverDetailPageState extends State<TaskHandoverDetailPage> {
  late final Future<List<UserProfile>> _candidates;
  final _note = TextEditingController();
  int? _recipient;
  String? _deadline;
  bool _saving = false;
  @override void initState() {
    super.initState();
    _candidates = widget.app.repo.handoverCandidates(widget.handover.id);
    _deadline = widget.handover.deadline;
  }
  @override void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _selectDeadline() async {
    final parsed = DateTime.tryParse(_deadline ?? '');
    final selected = await showDatePicker(context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      helpText: '调整交接任务的截止日期（须在交接说明中记录原因）');
    if (selected != null && mounted) {
      setState(() => _deadline = dayString(selected));
    }
  }

  Future<void> _confirm(List<UserProfile> candidates) async {
    final target = candidates.where((u) => u.id == _recipient).toList();
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择在职接手人')));
      return;
    }
    if (_note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写交接说明与剩余工作')));
      return;
    }
    final approved = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认任务交接？'),
        content: Text('将「${widget.handover.taskName}」交给${target.first.name}，'
          '保留原负责人及历史进度、日志；完成后不能重复交接。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认交接')),
        ]));
    if (approved != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.app.repo.confirmTaskHandover(widget.handover.id,
        newAssigneeId: target.first.id, note: _note.text.trim(), deadline: _deadline);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('交接失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override Widget build(BuildContext context) {
    final h = widget.handover;
    final stateLabel = const {
      'NOT_STARTED': '待开始',
      'IN_PROGRESS': '进行中',
      'BLOCKED': '受阻',
    }[h.executionStatus] ?? h.executionStatus;
    return Scaffold(appBar: AppBar(title: const Text('办理任务交接')),
      body: FutureBuilder<List<UserProfile>>(future: _candidates,
        builder: (context, snap) => ListView(
          padding: const EdgeInsets.all(18), children: [
            Text(h.taskName, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w900, color: Palette.deep)),
            const SizedBox(height: 10),
            Text('原负责人：${h.originalUserName}（账号已停用）'),
            Text('原执行状态：$stateLabel'),
            Text('已完成 ${h.progressPercent}% · 进度备注：${h.progressNote.isEmpty ? '无' : h.progressNote}'),
            Text('任务内容：${h.taskDetails}'),
            const SizedBox(height: 16),
            const Text('接手人（仅显示可接手的在职人员）',
              style: TextStyle(fontWeight: FontWeight.w800)),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: Padding(padding: EdgeInsets.all(20),
                child: CircularProgressIndicator()))
            else if (snap.hasError)
              Text('获取接手人失败：${snap.error}',
                style: const TextStyle(color: Palette.coral))
            else if ((snap.data ?? []).isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('没有可交接的在职人员，请联系上级管理员。'))
            else DropdownButtonFormField<int>(
              key: const Key('handover_successor_select'),
              initialValue: _recipient,
              isExpanded: true,
              hint: const Text('请选择接手人'),
              items: snap.data!.map((u) => DropdownMenuItem<int>(value: u.id,
                child: Text(u.name))).toList(),
              onChanged: _saving ? null : (id) => setState(() => _recipient = id)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _saving ? null : _selectDeadline,
              icon: const Icon(Icons.event),
              label: Text('截止日期：${_deadline ?? '未设置'}')),
            const SizedBox(height: 12),
            TextField(controller: _note, maxLines: 4, enabled: !_saving,
              key: const Key('handover_note'),
              decoration: const InputDecoration(labelText: '交接说明（必填）',
                hintText: '剩余工作、资料位置、风险和延期原因')),
            const SizedBox(height: 12),
            const Text('交接不会删除原员工的任务和日志，原进度会保留，实际改派须由后端确认。',
              style: TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _saving || snap.hasError ||
              (snap.data ?? []).isEmpty ? null : () => _confirm(snap.data!),
              child: Text(_saving ? '提交中…' : '确认交接')),
          ])),
      );
  }
}
