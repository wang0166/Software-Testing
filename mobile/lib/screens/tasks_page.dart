import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/ui.dart';
import 'dispatch_page.dart';
import 'task_progress_page.dart';
import 'published_task_detail_page.dart';

/// One searchable ledger for received assignments and my issued records.
/// The parent screen provides the vertical viewport; only columns scroll sideways.
class TasksPage extends StatefulWidget {
  final AppState app;
  final bool initiallyIssued;
  final Set<int> unreadTaskIds;
  final ValueChanged<int>? onTaskViewed;
  const TasksPage({super.key, required this.app, this.initiallyIssued = false,
    this.unreadTaskIds = const <int>{}, this.onTaskViewed});
  @override State<TasksPage> createState() => _TasksPageState();
}

class _LedgerItem {
  final TaskItem? received;
  final IssuedTask? issued;
  const _LedgerItem.received(TaskItem item) : received = item, issued = null;
  const _LedgerItem.issued(IssuedTask item) : received = null, issued = item;
  bool get isIssued => issued != null;
  String get title => received?.name ?? issued!.name;
  String get details => received?.details ?? issued!.details;
  String get taskType => received?.taskType ?? issued!.taskType;
  String get urgency => received?.urgency ?? issued!.urgency;
  String? get deadline => received?.deadline ?? issued?.deadline;
  String get assignee => isIssued ? '接收 ${issued!.assigneeCount} 人' : received!.assigneeName;
  String get state => isIssued ? issued!.stateLabel
      : received!.status == 'COMPLETED' ? '已完成' : '进行中';
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<TaskItem>> _received;
  late Future<IssuedTasksResult> _issued;
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  String _source = '全部来源';
  String _state = '全部状态';
  String _type = '全部类型';
  String _urgency = '全部优先级';
  String _order = '截止日期';
  bool _advanced = false;
  DateTimeRange? _dateRange;
  static const double rowHeight = 58;
  static const double tableWidth = 1114;

  @override void initState() {
    super.initState();
    if (widget.initiallyIssued) _source = '我发布的';
    _reload();
  }
  @override void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }
  void _reload() {
    _received = widget.app.repo.tasks(personal: false);
    _issued = widget.app.repo.issuedTasks();
  }
  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<dynamic>([
      _received.catchError((Object _) => <TaskItem>[]),
      _issued.catchError((Object _) => const IssuedTasksResult([])),
    ]);
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<TaskItem>>(
    future: _received, builder: (context, receivedSnap) =>
      FutureBuilder<IssuedTasksResult>(future: _issued, builder: (context, issuedSnap) {
        final waiting = receivedSnap.connectionState != ConnectionState.done ||
            issuedSnap.connectionState != ConnectionState.done;
        final received = receivedSnap.data ?? <TaskItem>[];
        final issued = issuedSnap.data?.items ?? <IssuedTask>[];
        final items = <_LedgerItem>[
          ...received.map(_LedgerItem.received),
          ...issued.map(_LedgerItem.issued),
        ];
        final types = <String>{
          'GENERAL', 'DEVELOPMENT', 'PRODUCT', 'TESTING',
          'OPERATION', 'SALES', 'ADMINISTRATIVE', _type,
          ...items.map((e) => e.taskType),
        }.toList()..sort();
        final issuedStates = <String>{
          '已发布', '派发待审核', '申请被驳回', '变更审核中',
          '审核已通过', '已撤回', _state,
          ...issued.map((e) => e.stateLabel),
        }.toList()..sort();
        final keyword = _search.text.trim().toLowerCase();
        final visible = items.where((entry) {
          if (_source == '收到的任务' && entry.isIssued) return false;
          if (_source == '我发布的' && !entry.isIssued) return false;
          if (_state != '全部状态' && entry.state != _state) return false;
          if (_type != '全部类型' && entry.taskType != _type) return false;
          if (_urgency != '全部优先级' && entry.urgency != _urgency) return false;
          if (_dateRange != null) {
            final date = DateTime.tryParse(entry.deadline ?? '');
            if (date == null) return false;
            final day = DateUtils.dateOnly(date);
            if (day.isBefore(_dateRange!.start) || day.isAfter(_dateRange!.end)) return false;
          }
          return keyword.isEmpty ||
            '${entry.title} ${entry.details} ${entry.assignee} ${taskTypeLabel(entry.taskType)} ${entry.state}'
              .toLowerCase().contains(keyword);
        }).toList();
        if (_order == '截止日期') {
          visible.sort((a, b) => (a.deadline ?? '9999').compareTo(b.deadline ?? '9999'));
        } else if (_order == '名称') {
          visible.sort((a, b) => a.title.compareTo(b.title));
        } else if (_order == '截止日期倒序') {
          visible.sort((a, b) => (b.deadline ?? '').compareTo(a.deadline ?? ''));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('任务执行台账', style: TextStyle(
                  color: Palette.deep, fontSize: 20, fontWeight: FontWeight.w900))),
                Text('共 ${visible.length} 项', style: const TextStyle(
                  color: Palette.primary, fontWeight: FontWeight.w800)),
                IconButton(onPressed: _refresh, tooltip: '刷新任务',
                  icon: const Icon(Icons.refresh, size: 21)),
              ]),
              const Text('统一筛选接收和发布记录 · 横向查看字段 · 点整行管理任务',
                style: TextStyle(color: Palette.muted, fontSize: 11)),
              const SizedBox(height: 9),
              SizedBox(height: 43, child: TextField(controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 19),
                  hintText: '搜索名称、内容、负责人、任务类型',
                  contentPadding: EdgeInsets.symmetric(vertical: 8)))),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _select(_source, ['全部来源', '收到的任务', '我发布的'],
                  (v) => setState(() => _source = v), width: 117),
                _select(_state, ['全部状态', '进行中', '已完成',
                    ...issuedStates],
                  (v) => setState(() => _state = v), width: 114),
                FilterChip(label: Text(_type != '全部类型' ||
                  _urgency != '全部优先级' || _dateRange != null
                    ? '高级筛选 · 已生效' : '高级筛选'),
                  selected: _advanced, showCheckmark: false,
                  onSelected: (v) => setState(() => _advanced = v)),
                if (_advanced) _select(_type, ['全部类型', ...types],
                  (v) => setState(() => _type = v), width: 106,
                  labels: (v) => v == '全部类型' ? v : taskTypeLabel(v)),
                if (_advanced) _select(_urgency, ['全部优先级', 'URGENT', 'NOT_URGENT'],
                  (v) => setState(() => _urgency = v), width: 112,
                  labels: (v) => const {'URGENT': '紧急', 'NOT_URGENT': '普通'}[v] ?? v),
                if (_advanced) _select(_order, ['截止日期', '截止日期倒序', '名称'],
                  (v) => setState(() => _order = v), width: 118),
                if (_advanced) OutlinedButton.icon(
                  onPressed: _pickDateRange, icon: const Icon(Icons.date_range, size: 16),
                  label: Text(_dateRange == null ? '截止日期筛选'
                    : '${_dateRange!.start.month}/${_dateRange!.start.day}—${_dateRange!.end.month}/${_dateRange!.end.day}',
                    style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                if (_dateRange != null || _source != '全部来源' ||
                  _state != '全部状态' || _type != '全部类型' ||
                  _urgency != '全部优先级' || _search.text.isNotEmpty)
                  TextButton(onPressed: () => setState(() {
                    _source = '全部来源'; _state = '全部状态'; _type = '全部类型';
                    _urgency = '全部优先级'; _dateRange = null; _search.clear();
                  }), child: const Text('清空筛选')),
              ]),
              if (issuedSnap.hasError) const Padding(
                padding: EdgeInsets.only(top: 5), child: Text(
                '发布记录暂不可用，当前仅显示已加载的接收任务',
                style: TextStyle(color: Palette.coral, fontSize: 11))),
            ])),
          Expanded(child: waiting ? const Center(child: CircularProgressIndicator())
            : receivedSnap.hasError && issuedSnap.hasError
              ? ErrorPanel(error: receivedSnap.error!, onRetry: _refresh)
              : visible.isEmpty
                ? const Center(child: BusinessEmpty('没有符合筛选条件的任务'))
                : _ledger(visible)),
        ]);
      }),
  );

  Widget _select(String value, List<String> options, ValueChanged<String> changed,
    {required double width, String Function(String)? labels}) =>
    SizedBox(width: width, height: 39,
      child: DropdownButtonFormField<String>(key: ValueKey('${options.first}_$value'),
        initialValue: value, isExpanded: true,
        decoration: const InputDecoration(contentPadding:
          EdgeInsets.symmetric(horizontal: 8, vertical: 5)),
        style: const TextStyle(color: Palette.deep, fontSize: 11,
          fontWeight: FontWeight.w700),
        items: options.toSet().map((v) => DropdownMenuItem(
          value: v, child: Text(labels?.call(v) ?? v,
            maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) changed(v); },
      ),
    );

  Future<void> _pickDateRange() async {
    final now = chinaNow;
    final range = await showDateRangePicker(context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: _dateRange,
      currentDate: now,
      helpText: '按任务截止日期筛选');
    if (mounted && range != null) setState(() => _dateRange = range);
  }

  Widget _ledger(List<_LedgerItem> items) => Scrollbar(
    controller: _horizontal, thumbVisibility: true,
    notificationPredicate: (notification) =>
      notification.metrics.axis == Axis.horizontal,
    child: SingleChildScrollView(
      key: const Key('task_ledger_horizontal'), controller: _horizontal,
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: tableWidth, child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const Key('task_ledger_vertical'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverList.builder(itemCount: items.length,
              itemBuilder: (context, index) => _row(items[index], index)),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      )),
    ),
  );

  Widget _header() => Container(height: 43, color: Palette.deep,
    child: Row(children: [
      _heading('序号', 50), _heading('任务名称', 232),
      _heading('来源', 93), _heading('任务类型', 100),
      _heading('执行 / 审核状态', 138), _heading('截止日期', 154),
      _heading('优先级', 89), _heading('负责人 / 接收人', 133),
      _heading('任务内容', 125),
    ]));

  Widget _heading(String value, double width) => SizedBox(width: width,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Align(alignment: Alignment.centerLeft, child: Text(value,
        style: const TextStyle(color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.w800)))));

  Widget _cell(String value, double width, {Color? ink, bool strong = false,
    Widget? child}) => Container(width: width,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(border: Border(right:
      BorderSide(color: Palette.divider, width: .6))),
    child: child ?? Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink ?? Palette.deep, fontSize: 11.5,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500)));

  Widget _tag(String label, Color ink) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: ink.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5)),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)),
  );

  Widget _row(_LedgerItem item, int index) => Material(
    color: index.isEven ? Colors.white : const Color(0xFFF2F6F9),
    child: InkWell(onTap: () => item.isIssued
      ? _issuedActions(item.issued!) : _receivedDetail(item.received!),
      child: Container(height: rowHeight,
        decoration: const BoxDecoration(border: Border(bottom:
          BorderSide(color: Palette.divider, width: .65))),
        child: Row(children: [
          _cell('${index + 1}', 50, ink: Palette.muted),
          _cell(item.title, 232, strong: true, child: Row(children: [
            if (!item.isIssued && widget.unreadTaskIds.contains(item.received!.id))
              const Padding(padding: EdgeInsets.only(right: 7), child:
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF2267B5))),
            Expanded(child: Text(item.title, maxLines: 2,
              overflow: TextOverflow.ellipsis, style: const TextStyle(
                color: Palette.deep, fontSize: 12, fontWeight: FontWeight.w800))),
          ])),
          _cell('', 93, child: _tag(item.isIssued ? '我发布的' : '收到的',
            item.isIssued ? Palette.primary : const Color(0xFF66778C))),
          _cell('', 100, child: _tag(taskTypeLabel(item.taskType),
            taskTypeColor(item.taskType))),
          _cell('', 138, child: _tag(item.state,
            item.state == '已完成' ? const Color(0xFF168370)
            : item.state.contains('驳回') ? Palette.coral
            : const Color(0xFFB17B2A))),
          _cell((item.deadline ?? '未设置').replaceFirst('T', ' '), 154),
          _cell('', 89, child: _tag(item.urgency == 'URGENT' ? '紧急' : '普通',
            item.urgency == 'URGENT' ? Palette.coral : Palette.primary)),
          _cell(item.assignee.isEmpty ? '我' : item.assignee, 133),
          _cell(item.details.isEmpty ? '—' : item.details, 125, ink: Palette.muted),
        ]),
      ),
    ),
  );

  Future<void> _receivedDetail(TaskItem item) async {
    widget.onTaskViewed?.call(item.id);
    await Navigator.push<void>(context, MaterialPageRoute<void>(
      builder: (_) => TaskProgressPage(app: widget.app, task: item)));
    if (mounted) setState(_reload);
  }
  Future<void> _issuedActions(IssuedTask item) async {
    final action = await showModalBottomSheet<String>(context: context,
      showDragHandle: true, builder: (sheet) => SafeArea(child:
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(item.name, style: const TextStyle(
              color: Palette.deep, fontWeight: FontWeight.w800)),
              subtitle: Text(item.stateLabel)),
            ListTile(leading: const Icon(Icons.visibility_outlined),
              title: const Text('查看详情'),
              onTap: () => Navigator.pop(sheet, 'detail')),
            ListTile(leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑任务'),
              enabled: !item.changePending && (!item.isRequest || item.isWaiting),
              onTap: () => Navigator.pop(sheet, 'edit')),
            ListTile(leading: const Icon(Icons.delete_outline, color: Palette.coral),
              title: Text(item.isRequest ? '撤回派发申请' : '申请删除任务'),
              enabled: !item.changePending && (!item.isRequest || item.isWaiting),
              onTap: () => Navigator.pop(sheet, 'delete')),
          ]))),
    );
    if (!mounted) return;
    if (action == 'detail') {
      await Navigator.push<void>(context, MaterialPageRoute<void>(
        builder: (_) => PublishedTaskDetailPage(app: widget.app, issued: item)));
    } else if (action == 'edit') {
      await Navigator.push<bool>(context, MaterialPageRoute<bool>(
        builder: (_) => DispatchPage(app: widget.app, editing: item)));
    } else if (action == 'delete') {
      await _deleteIssued(item);
    }
    if (mounted && action != null) setState(_reload);
  }

  Future<void> _deleteIssued(IssuedTask item) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.isRequest ? '撤回派发申请？' : '提交删除任务申请？'),
        content: Text(item.isRequest ? '待审核的申请将被撤回。'
          : '删除需管理员审核，在审核通过前原任务仍有效。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final status = await widget.app.repo.requestIssuedTaskDelete(item);
      if (mounted) {
        toast(context, status == 'WITHDRAWN'
          ? '派发申请已撤回' : '删除申请已提交，等待审核');
      }
    } catch (e) {
      if (mounted) toast(context, '操作失败：$e');
    }
  }
}
