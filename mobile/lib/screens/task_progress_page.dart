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

  String get _status => current.status == 'COMPLETED' ? '已完成' : '进行中';

  Future<void> _change(String status) async {
    if (_saving || current.status == 'COMPLETED') return;
    if (status == 'COMPLETED') {
      final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认任务已完成？'),
          content: const Text('完成后不能再直接改为进行中，后续检查由原审批流程处理。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认完成')),
          ],
        ));
      if (confirmed != true || !mounted) return;
    }
    // Compatibility with the existing progress API: it still requires a
    // percentage, though the simplified mobile UI no longer requests one.
    final percent = status == 'COMPLETED' ? 100
      : (current.progressPercent ?? 0).clamp(0, 99).toInt();
    setState(() => _saving = true);
    try {
      await widget.app.repo.updateTaskProgress(current,
        status: status, percent: percent, note: '');
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'COMPLETED' ? '已标记完成' : '已设为进行中')));
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
              const Text('只需选择“进行中”或“已完成”，无需填写完成率和进度备注。',
                style: TextStyle(color: Palette.muted, fontSize: 12)),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  key: const Key('task_status_in_progress'),
                  onPressed: _saving || current.status == 'COMPLETED'
                    ? null : () => _change('IN_PROGRESS'),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('进行中'))),
                const SizedBox(width: 9),
                Expanded(child: FilledButton.icon(
                  key: const Key('task_status_completed'),
                  onPressed: _saving || current.status == 'COMPLETED'
                    ? null : () => _change('COMPLETED'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('已完成'))),
              ]),
              if (current.status == 'COMPLETED' &&
                  (current.reviewStatus == 'NONE' || current.reviewStatus == 'RETURNED')) ...[
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _saving ? null : _inviteReview,
                  child: const Text('申请完成检查')),
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
