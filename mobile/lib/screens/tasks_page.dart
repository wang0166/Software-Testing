import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';

/// 甲方任务台账：可双向滚动、固定表头、任务详情与状态推进保留。
/// 仅展示当前后端授权的收到任务；创建入口由 ViewPage 统一提供。
class TasksPage extends StatefulWidget {
  final AppState app;
  const TasksPage({super.key, required this.app});
  @override State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<TaskItem>> _future;
  final search = TextEditingController();
  final _horizontal = ScrollController();
  String filter = '全部';
  static const double tableWidth = 1120;
  static const double rowHeight = 54;
  @override void initState() {super.initState(); _reload();}
  @override void dispose() {search.dispose(); _horizontal.dispose(); super.dispose();}
  void _reload() {_future = widget.app.repo.tasks(personal: false);}

  Future<void> _advance(TaskItem task) async {
    final next = task.status == 'NOT_STARTED' ? 'IN_PROGRESS'
        : task.status == 'IN_PROGRESS' ? 'COMPLETED' : null;
    if (next == null) return;
    try {
      await widget.app.repo.updateTask(task, next);
      if (mounted) {toast(context, '任务进度已更新'); setState(_reload);}
    } catch(e) {if (mounted) toast(context, '$e');}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TaskItem>>(
    future: _future,
    builder: (context, snap) {
      final tasks = snap.data ?? <TaskItem>[];
      final keyword = search.text.trim().toLowerCase();
      final visible = tasks.where((t) =>
        (filter == '全部' || filter == t.statusLabel) &&
        (keyword.isEmpty || t.name.toLowerCase().contains(keyword) ||
          t.details.toLowerCase().contains(keyword))
      ).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 9, 16, 8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('任务执行台账', style: TextStyle(
                color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 19))),
              Text('共 ${visible.length} 项', style: const TextStyle(color: Palette.primary,
                fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            const Text('左右滑动查看更多字段 · 上下滑动查看全部任务 · 点行查看详情',
              style: TextStyle(color: Palette.muted, fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SizedBox(height: 42, child: TextField(
                controller: search, onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18),
                  hintText: '搜索任务名称或进度备注', contentPadding: EdgeInsets.symmetric(vertical: 7))))),
              const SizedBox(width: 9),
              SizedBox(width: 102, child: DropdownButtonFormField<String>(
                key: ValueKey(filter), initialValue: filter, isExpanded: true,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8)),
                style: const TextStyle(color: Palette.deep, fontSize: 12, fontWeight: FontWeight.w700),
                items: ['全部','待开始','进行中','已完成'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                onChanged: (v) {if(v != null) setState(() => filter = v);},
              )),
            ]),
          ],
        )),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : snap.hasError
              ? ErrorPanel(error: snap.error!, onRetry: () => setState(_reload))
              : visible.isEmpty
                ? const Center(child: BusinessEmpty('当前没有匹配的接收任务'))
                : RefreshIndicator(
                    onRefresh: () async {setState(_reload); await _future;},
                    child: _ledger(visible),
                  ),
        )),
        const SizedBox(height: 64), // 避开 ViewPage 的「创建任务」悬浮入口
      ]);
    },
  );

  Widget _ledger(List<TaskItem> tasks) => Container(
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias,
    child: Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        key: const Key('task_ledger_horizontal'),
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: Column(children: [
          _header(),
          Expanded(child: Scrollbar(child: ListView.builder(
            key: const Key('task_ledger_vertical'),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemExtent: rowHeight,
            itemBuilder: (context, i) => _row(tasks[i], i),
          ))),
        ])),
      ),
    ),
  );

  Widget _cell(String text, double width, {Color? ink, FontWeight? weight,
    Alignment alignment = Alignment.centerLeft, int maxLines = 2}) =>
    Container(width: width, alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Palette.divider, width: .55))),
      child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ink ?? Palette.deep, fontSize: 11.5,
          height: 1.25, fontWeight: weight ?? FontWeight.w500)));

  Widget _header() => Container(
    height: 44, color: Palette.deep,
    child: Row(children: [
      _heading('序号', 47), _heading('任务名称', 250), _heading('任务类型', 91),
      _heading('截止日期', 150), _heading('紧急程度', 104), _heading('完成情况', 114),
      _heading('进度备注 / 详情', 244), _heading('负责人', 120),
    ]),
  );

  Widget _heading(String label, double width) => SizedBox(width: width,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Align(alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w800, fontSize: 11)))));

  Widget _tag(String text, Color color) => Container(
    constraints: const BoxConstraints(maxWidth: 102),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(4)),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
  );

  Widget _tagCell(Widget tag, double width) => Container(width: width,
    alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Palette.divider, width: .55))),
    child: tag);

  Widget _row(TaskItem task, int i) => Material(
    color: i.isEven ? Colors.white : const Color(0xFFF3F6F9),
    child: InkWell(onTap: () => _detail(task),
      child: Container(height: rowHeight,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.divider, width: .65))),
        child: Row(children: [
          _cell('${i + 1}', 47, ink: Palette.muted),
          _cell(task.name, 250, weight: FontWeight.w800),
          _tagCell(_tag(taskTypeLabel(task.taskType), taskTypeColor(task.taskType)), 91),
          _cell(_shortDate(task.deadline), 150),
          _tagCell(_tag(task.urgency == 'URGENT' ? '紧急' : '普通',
            task.urgency == 'URGENT' ? const Color(0xFFD46840) : const Color(0xFF187B68)), 104),
          _tagCell(_tag(task.statusLabel,
            task.status == 'COMPLETED' ? const Color(0xFF087D79)
              : task.status == 'IN_PROGRESS' ? const Color(0xFFB47A24) : const Color(0xFF6B7886)), 114),
          _cell(task.progressNote.isNotEmpty ? task.progressNote :
            (task.details.isNotEmpty ? task.details : '—'), 244, ink: Palette.muted),
          _cell(task.assigneeName.isNotEmpty ? task.assigneeName : (widget.app.user?.name ?? '我'), 120),
        ]),
      ),
    ),
  );
  String _shortDate(String? raw) => raw == null || raw.isEmpty ? '未设置' : raw.replaceFirst('T', ' ');

  void _detail(TaskItem item) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (ctx) => SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.name, style: const TextStyle(color: Palette.deep,
            fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [
            _tag(taskTypeLabel(item.taskType), taskTypeColor(item.taskType)),
            _tag(item.statusLabel, Palette.primary),
          ]),
          const SizedBox(height: 14), Text(item.details.isEmpty ? '暂无详细说明' : item.details,
            style: const TextStyle(height: 1.6)),
          const SizedBox(height: 11), Text('起始：${_shortDate(item.startDate)}\n截止：${_shortDate(item.deadline)}',
            style: const TextStyle(color: Palette.muted, height: 1.6)),
          if(item.progressNote.isNotEmpty) ...[
            const SizedBox(height: 10), Text('进度备注：${item.progressNote}')],
          const SizedBox(height: 18),
          if(item.status != 'COMPLETED') FilledButton(
            onPressed: () {Navigator.pop(ctx); _advance(item);},
            child: Text(item.status == 'NOT_STARTED' ? '开始任务' : '标记完成')),
          if(item.status == 'COMPLETED' &&
            (item.reviewStatus == 'NONE' || item.reviewStatus == 'RETURNED'))
            FilledButton(onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.app.repo.inviteReview(item.id);
                if(mounted) {toast(context, '已提交完成检查'); setState(_reload);}
              } catch(e) {if(mounted) toast(context, '$e');}
            }, child: const Text('邀请完成检查')),
        ],
      )),
    )),
  );
}
