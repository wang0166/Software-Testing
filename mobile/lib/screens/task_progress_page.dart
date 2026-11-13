import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';

/// Simple two-state execution UI. Existing server history and review workflow
/// remain available, but users do not need to enter percentages or notes.
class TaskProgressPage extends StatefulWidget {
  final AppState app;
  final TaskItem task;
  const TaskProgressPage({super.key, required this.app, required this.task});
  @override State<TaskProgressPage> createState() => _TaskProgressPageState();
}

class _TaskProgressPageState extends State<TaskProgressPage> {
  late TaskItem current;
  late Future<List<TaskProgressRecord>> _history;
  bool _saving = false;
  // Prevent a stale task-list response from re-enabling the completion action
  // immediately after the server has accepted the completion record.
  bool _completionSubmitted = false;

  @override void initState() {
    super.initState();
    current = widget.task;
    _history = widget.app.repo.taskProgressHistory(current.id);
  }

  Future<void> _refresh() async {
    try {
      final tasks = await widget.app.repo.tasks(personal: false);
      if (!mounted) return;
      setState(() {
        for (final task in tasks) {
          if (task.id == current.id) { current = task; break; }
        }
        _history = widget.app.repo.taskProgressHistory(current.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新任务失败：$e')));
      }
    }
  }

  bool get _isCompleted => current.status == 'COMPLETED' || _completionSubmitted;
  String get _status => _isCompleted ? '已完成' : '进行中';

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
  }

  String _completionTime(List<TaskProgressRecord>? records) {
    DateTime? latest;
    for (final record in records ?? const <TaskProgressRecord>[]) {
      if (record.status != 'COMPLETED') continue;
      final parsed = DateTime.tryParse(record.createdAt.replaceFirst(' ', 'T'));
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
      }
    }
    // Older backend versions only expose the last progress update time.
    if (latest == null && current.status == 'COMPLETED') {
      final raw = current.progressUpdatedAt;
      if (raw != null) {
        latest = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      }
    }
    return latest == null ? '等待后端同步' : _formatTimestamp(latest);
  }

  Future<void> _completeTask() async {
    if (_saving || _isCompleted || current.source != 'RECEIVED') return;
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认任务已完成？'),
        content: const Text('标记完成后不能直接改回进行中。如需完成检查，仍须按原有审核流程操作。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认完成')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      // Keep the existing backend API and its ownership / review checks.
      // Only the mobile interaction is simplified; the API still needs 100%.
      await widget.app.repo.updateTaskProgress(current,
        status: 'COMPLETED', percent: 100, note: '');
      if (!mounted) return;
      setState(() {
        _completionSubmitted = true;
        _history = widget.app.repo.taskProgressHistory(current.id);
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记完成')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('状态更新失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _inviteReview() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.app.repo.inviteReview(current.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已申请完成检查，等待审核')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('申请失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('任务详情')),
    body: RefreshIndicator(onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 13, 16, 35),
        children: [
          Container(padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Palette.deep,
              borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(current.name, style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 11),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text(taskTypeLabel(current.taskType), style: TextStyle(
                  color: taskTypeColor(current.taskType), fontWeight: FontWeight.w800)),
                  backgroundColor: Colors.white),
                Chip(label: Text(_status), backgroundColor: const Color(0xFFE2F3EF)),
                if (current.urgency == 'URGENT')
                  const Chip(label: Text('紧急'), backgroundColor: Color(0xFFFFD8C9)),
              ]),
            ])),
          const SizedBox(height: 12),
          BusinessPanel(title: '任务信息', child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(current.details.isEmpty ? '暂无任务说明' : current.details,
                style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 9),
              _field('负责人', current.assigneeName.isEmpty
                ? widget.app.user?.name ?? '我' : current.assigneeName),
              _field('开始时间', (current.startDate ?? '未设置').replaceFirst('T', ' ')),
              _field('截止时间', (current.deadline ?? '未设置').replaceFirst('T', ' ')),
            ]))),
          const SizedBox(height: 12),
          BusinessPanel(title: '执行状态', child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Text('当前状态', style: TextStyle(
                  color: Palette.muted, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isCompleted ? const Color(0xFFE2F3EF)
                      : const Color(0xFFE9F0F8),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(_status, style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _isCompleted ? const Color(0xFF137E71) : Palette.deep)),
                ),
              ]),
              if (_isCompleted) ...[
                const SizedBox(height: 8),
                FutureBuilder<List<TaskProgressRecord>>(
                  future: _history,
                  builder: (context, snap) => _field('完成时间',
                    snap.connectionState == ConnectionState.done
                      ? _completionTime(snap.data) : '正在读取记录…'),
                ),
                if (current.reviewStatus == 'PENDING')
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('已申请完成检查，等待审核',
                      style: TextStyle(color: Palette.muted, fontSize: 12))),
                if (current.reviewStatus == 'APPROVED')
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('完成检查已通过',
                      style: TextStyle(color: Palette.muted, fontSize: 12))),
                if (current.source == 'RECEIVED' &&
                    (current.reviewStatus == 'NONE' || current.reviewStatus == 'RETURNED')) ...[
                  const SizedBox(height: 11),
                  OutlinedButton(onPressed: _saving ? null : _inviteReview,
                    child: const Text('申请完成检查')),
                ],
              ] else if (current.source == 'RECEIVED') ...[
                const SizedBox(height: 13),
                FilledButton.icon(
                  key: const Key('task_mark_completed'),
                  onPressed: _saving ? null : _completeTask,
                  icon: _saving ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                  label: const Text('标记为已完成'),
                ),
              ],
            ]))),
          const SizedBox(height: 12),
          BusinessPanel(title: '历史记录（可展开）', child: Material(
            color: Colors.transparent,
            child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('查看以往状态和审核记录', style: TextStyle(fontSize: 13)),
            children: [FutureBuilder<List<TaskProgressRecord>>(
              future: _history, builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator());
                }
                if (snap.hasError) return Text('历史记录暂不可用：${snap.error}');
                final records = snap.data ?? [];
                if (records.isEmpty) return const Text('暂无历史记录');
                return Column(children: [for (final record in records)
                  ListTile(dense: true, title: Text(
                    '${record.status == 'COMPLETED' ? '已完成' : '进行中'} · ${record.authorName}'),
                    subtitle: Text('${record.createdAt.replaceFirst('T', ' ')}'
                      '${record.note.isEmpty ? '' : '\n${record.note}'}')),
                ]);
              },
            )],
          ))),
        ],
      ),
    ),
  );

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 85, child: Text(label,
        style: const TextStyle(color: Palette.muted, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(
        color: Palette.deep, fontWeight: FontWeight.w700, fontSize: 12))),
    ]),
  );
}
