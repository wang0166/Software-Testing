import 'package:flutter/material.dart';
import '../core/gantt_utils.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/task_gantt_chart.dart';
import '../widgets/ui.dart';
import '../widgets/redesign.dart';
import '../widgets/business.dart';

/// Month/week/day task calendar and full Gantt view.
/// As required by the client, calendar views never request or display log data.
/// Task counts and day markers are derived solely from authorized received tasks.
class CalendarPage extends StatefulWidget {
  final AppState app;
  final int initialMode; // 0 month, 1 week, 2 day, 3 gantt
  final DateTime? initialDate;
  final bool embedded;

  const CalendarPage({
    super.key,
    required this.app,
    this.initialMode = 0,
    this.initialDate,
    this.embedded = false,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late int _mode;
  late Future<List<TaskItem>> _receivedTasks;

  DateTime get _monthLast => DateTime(_month.year, _month.month + 1, 0);
  DateTime get _weekFirst => DateTime(_selected.year, _selected.month, _selected.day)
      .subtract(Duration(days: _selected.weekday - 1));
  DateTime get _rangeLast => _mode == 1
      ? _weekFirst.add(const Duration(days: 6))
      : _mode == 2
          ? _selected
          : _monthLast;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? chinaNow;
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _mode = widget.initialMode < 0
        ? 0
        : widget.initialMode > 3
            ? 3
            : widget.initialMode;
    _reload();
  }

  void _reload() {
    final allowed = widget.app.user?.canUseTasks ?? false;
    _receivedTasks = allowed
        ? widget.app.repo.tasks(personal: false)
        : Future.value(<TaskItem>[]);
  }

  void _changeMode(int mode) {
    setState(() {
      _mode = mode;
      _month = DateTime(_selected.year, _selected.month);
      _reload();
    });
  }

  void _shift(int offset) {
    setState(() {
      if (_mode == 0 || _mode == 3) {
        _month = DateTime(_month.year, _month.month + offset);
        _selected = DateTime(_month.year, _month.month, 1);
      } else {
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day + offset * (_mode == 1 ? 7 : 1),
        );
        _month = DateTime(_selected.year, _selected.month);
      }
      _reload();
    });
  }

  void _goToday() {
    final now = chinaNow;
    setState(() {
      _selected = DateTime(now.year, now.month, now.day);
      _month = DateTime(now.year, now.month);
      _reload();
    });
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _receivedTasks;
    } catch (_) {
      // FutureBuilders show the corresponding error/retry state.
    }
  }

  String get _periodText {
    if (_mode == 1) {
      return '${_weekFirst.month}/${_weekFirst.day} — ${_rangeLast.month}/${_rangeLast.day}';
    }
    if (_mode == 2) {
      return '${_selected.year} 年 ${_selected.month} 月 ${_selected.day} 日';
    }
    return '${_month.year} 年 ${_month.month} 月';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const Text('日历视图')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
              children: [
                const BusinessHeading(title: '日历视图', subtitle: '只展示任务安排，支持年月日快速选择'),
                const SizedBox(height: 18),
                _controls(),
                const SizedBox(height: 17),
                if (_mode == 3)
                  _taskChart(full: true)
                else ...[
                  _calendarContents(),
                  if (_mode != 2) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: _openFullGantt,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('查看完整甘特图', style: TextStyle(
                            color: Palette.primary, fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline)),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selected,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '选择年、月、日',
      cancelText: '取消', confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _month = DateTime(picked.year, picked.month);
      _reload();
    });
  }

  Widget _controls() => StoryCard(
        color: Palette.mutedBlue,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 15),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上一时间段',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('calendar_date_picker'),
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(child: Text(_periodText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Palette.deep))),
                      const SizedBox(width: 5), const Icon(Icons.arrow_drop_down_circle_outlined, size: 19, color: Palette.primary),
                    ])),
                  ),
                ),
                TextButton(
                  onPressed: _goToday,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Palette.primary,
                  ),
                  child: const Text('今天', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: '下一时间段',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        key: ValueKey('calendar_mode_$i'),
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => _changeMode(i),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == i ? Palette.deep : Colors.white,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            const ['月', '周', '日', '甘特图'][i],
                            style: TextStyle(
                              color: _mode == i ? Colors.white : Palette.deep,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _Legend(color: Color(0xFFF3D8AA), label: '待开始'),
                _Legend(color: Color(0xFFC7D9EC), label: '进行中'),
                _Legend(color: Color(0xFFC7E5DD), label: '已完成'),
              ],
            ),
          ],
        ),
      );

  // The reference-inspired month view places pastel date-range bars directly
  // inside each week instead of repeating an independent chart below the grid.
  // Assigned-task spans are clipped by week and shown on collision-free lanes.
  // The backend calendar endpoint mixes task counts with log-related data.
  // This page intentionally uses only the received-task endpoint.
  Widget _calendarContents() => FutureBuilder<List<TaskItem>>(
        future: _receivedTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorPanel(
              error: snapshot.error!,
              onRetry: () => setState(_reload),
            );
          }
          final tasks = snapshot.data ?? <TaskItem>[];
          return _mode == 2 ? _dayView(tasks) : _weeksView(tasks);
        },
      );

  // 以独立页面打开完整甘特图，而不是把月历直接替换掉。
  void _openFullGantt() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => CalendarPage(
        app: widget.app, initialMode: 3, initialDate: _selected),
    ));
  }

  Widget _moreTasksLink(int hidden, {String? dateLabel}) => Align(
    alignment: Alignment.centerRight,
    child: Semantics(
      link: true,
      label: '查看更多任务，打开完整甘特图',
      child: InkWell(
        key: const Key('calendar_more_tasks'),
        onTap: _openFullGantt,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          child: Text('${dateLabel == null ? '' : '$dateLabel · '}还有 $hidden 项任务 · 查看完整甘特图',
            style: const TextStyle(color: Palette.primary, fontSize: 12,
              fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
        ),
      ),
    ),
  );

  Widget _weeksView(List<TaskItem> tasks) {
    final first = _mode == 0
        ? _month.subtract(Duration(days: _month.weekday - 1))
        : _weekFirst;
    final totalDays = _mode == 1
        ? 7
        : ((_monthLast.day + _month.weekday - 1 + 6) ~/ 7) * 7;
    final numberOfWeeks = totalDays ~/ 7;
    return StoryCard(
      padding: const EdgeInsets.fromLTRB(12, 17, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final name in const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'])
                Expanded(
                  child: Center(
                    child: Text(name, style: const TextStyle(
                      color: Palette.deep, fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var weekIndex = 0; weekIndex < numberOfWeeks; weekIndex++)
            _weekRow(first.add(Duration(days: weekIndex * 7)), tasks),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          _dayInfo(tasks),
          const SizedBox(height: 8),
          const Text(
            '彩色横条代表任务的起止日期，点击查看任务详情',
            style: TextStyle(color: Palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weekRow(DateTime weekFirst, List<TaskItem> tasks) {
    // Allocate ALL task lanes; the three-lane viewport is independently
    // scrollable when a date contains more than three overlapping tasks.
    final spans = buildGanttSpans(
      tasks,
      weekFirst,
      weekFirst.add(const Duration(days: 6)),
    );
    final rows = allocateGanttLanes(spans);
    final usedLanes = rows.isEmpty
        ? 0
        : rows.map((row) => row.lane).reduce((a, b) => a > b ? a : b) + 1;
    final hidden = rows.where((row) => row.lane >= 3).length;
    final overflowDates = <DateTime>[];
    for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
      final active = spans.where((span) =>
        span.startColumn <= dayIndex &&
        dayIndex < span.startColumn + span.dayCount).length;
      if (active > 3) overflowDates.add(weekFirst.add(Duration(days: dayIndex)));
    }
    final barsHeight = usedLanes == 0 ? 12.0 : usedLanes * 26.0 + 7.0;
    final visibleHeight = usedLanes > 3 ? 3 * 26.0 + 7.0 : barsHeight;
    return Container(
      padding: const EdgeInsets.only(bottom: 5, top: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 41,
            child: Row(
              children: [
                for (var dayIndex = 0; dayIndex < 7; dayIndex++)
                  Expanded(
                    child: _dateCell(
                      weekFirst.add(Duration(days: dayIndex)),
                      tasks,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: visibleHeight,
            child: Scrollbar(
              child: SingleChildScrollView(
                key: ValueKey('calendar_week_task_scroll_${dayString(weekFirst)}'),
                primary: false,
                scrollDirection: Axis.vertical,
                physics: usedLanes > 3
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: barsHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellWidth = constraints.maxWidth / 7;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (final entry in rows)
                            Positioned(
                              left: entry.span.startColumn * cellWidth + 1.5,
                              top: entry.lane * 26.0 + 4,
                              width: (entry.span.dayCount * cellWidth - 3.0)
                                  .clamp(4.0, constraints.maxWidth).toDouble(),
                              height: 23,
                              child: Material(
                                color: _barColor(entry.span.task.status),
                                borderRadius: BorderRadius.circular(6),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _showTaskDetails(entry.span.task),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        entry.span.task.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _barInk(entry.span.task.status),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (hidden > 0)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('任务区可上下滑动查看剩余任务',
                  style: TextStyle(fontSize: 10, color: Palette.muted)),
              ),
            ),
          if (hidden > 0) _moreTasksLink(hidden,
            dateLabel: overflowDates.isEmpty ? null :
                '${overflowDates.first.month}月${overflowDates.first.day}日${overflowDates.length > 1 ? '等日期' : ''}'),
        ],
      ),
    );
  }

  Widget _dateCell(DateTime date, List<TaskItem> tasks) {
    final isSelected = dayString(date) == dayString(_selected);
    final isToday = dayString(date) == todayChina;
    final sameMonth = _mode == 1 ||
        (date.year == _month.year && date.month == _month.month);
    final hasTasks = buildGanttSpans(tasks, date, date).isNotEmpty;
    return InkWell(
      key: ValueKey('calendar_day_${dayString(date)}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          final changedMonth = _month.year != date.year || _month.month != date.month;
          _selected = date;
          _month = DateTime(date.year, date.month);
          if (changedMonth) _reload();
        });
      },
      child: Column(
        children: [
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? Palette.primary
                  : isToday
                      ? Palette.sage
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : sameMonth
                        ? Palette.deep
                        : Palette.muted,
                fontSize: 12,
                fontWeight: isToday || isSelected
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            ),
          ),
          if (hasTasks)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayView(List<TaskItem> tasks) {
    final todaySpans = buildGanttSpans(tasks, _selected, _selected);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dayInfo(tasks),
          if (todaySpans.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              '这一天进行的任务',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.deep),
            ),
            const SizedBox(height: 10),
            if (todaySpans.length <= 3)
              for (final span in todaySpans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _dayTaskTile(span.task),
                )
            else ...[
              const Text('在任务列表内上下滑动，可查看当天全部任务',
                style: TextStyle(color: Palette.muted, fontSize: 11)),
              const SizedBox(height: 9),
              SizedBox(
                height: 3 * 72.0,
                child: Scrollbar(
                  child: ListView.builder(
                    key: const Key('calendar_day_task_scroll'),
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    itemCount: todaySpans.length,
                    itemExtent: 72,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _dayTaskTile(todaySpans[index].task),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _moreTasksLink(todaySpans.length - 3),
            ],
          ],
        ],
      ),
    );
  }

  Widget _dayTaskTile(TaskItem task) => Material(
    color: _barColor(task.status),
    borderRadius: BorderRadius.circular(9),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      onTap: () => _showTaskDetails(task),
      leading: const Icon(Icons.event_note_outlined, color: Palette.deep),
      title: Text(task.name,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      subtitle: Text(task.statusLabel),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );

  Color _barColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFFC7E5DD);
      case 'IN_PROGRESS':
        return const Color(0xFFC7D9EC);
      default:
        return const Color(0xFFF3D8AA);
    }
  }

  Color _barInk(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF25684A);
      case 'IN_PROGRESS':
        return const Color(0xFF53477E);
      default:
        return const Color(0xFF7B581D);
    }
  }

  Widget _taskChart({required bool full}) => FutureBuilder<List<TaskItem>>(
        future: _receivedTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ErrorPanel(error: snapshot.error!, onRetry: () => setState(_reload));
          }
          final start = _mode == 1 ? _weekFirst : _month;
          final end = _mode == 1 ? _rangeLast : _monthLast;
          return Column(
            children: [
              TaskGanttChart(
                tasks: snapshot.data ?? <TaskItem>[],
                rangeStart: start,
                rangeEnd: end,
                selectedDate: _selected,
                full: full,
                onTaskTap: _showTaskDetails,
              ),
              if (!full) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _changeMode(3),
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('查看完整甘特图'),
                  ),
                ),
              ],
            ],
          );
        },
      );

  void _showTaskDetails(TaskItem task) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('派发任务详情', style: TextStyle(color: Palette.muted, fontSize: 12)),
                const SizedBox(height: 9),
                Text(task.name, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(task.details,
                    style: const TextStyle(color: Palette.deep, height: 1.6)),
                const SizedBox(height: 15),
                StatusBadge(status: task.status),
                const SizedBox(height: 12),
                Text('开始：${task.startDate ?? '未提供'}',
                    style: const TextStyle(color: Palette.deep)),
                const SizedBox(height: 6),
                Text('截止：${task.deadline ?? '未提供'}',
                    style: const TextStyle(color: Palette.deep)),
                const SizedBox(height: 19),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('返回日历'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayInfo(List<TaskItem> tasks) {
    final selected = dayString(_selected);
    final taskCount = buildGanttSpans(tasks, _selected, _selected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selected.month}月${_selected.day}日 · 任务安排',
          style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Palette.deep,
          ),
        ),
        const SizedBox(height: 11),
        if (taskCount == 0)
          const EmptyPanel(
            title: '当天暂无任务',
            subtitle: '可以通过右下角「创建任务」发起新的派发申请',
            icon: Icons.event_available_outlined,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Palette.divider),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(children: [
              const Icon(Icons.task_alt_rounded, color: Palette.primary, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text('当天共有 $taskCount 项任务',
                style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w700))),
            ]),
          ),
        const SizedBox(height: 8),
        Text('日期 $selected · 仅显示已授权的任务安排',
          style: const TextStyle(color: Palette.muted, fontSize: 11)),
      ],
    );
  }

}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Palette.muted, fontSize: 11)),
        ],
      );
}
