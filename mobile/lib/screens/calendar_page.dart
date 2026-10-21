import 'package:flutter/material.dart';
import '../core/gantt_utils.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/task_gantt_chart.dart';
import '../widgets/ui.dart';

/// Month/week/day calendar plus a date-range Gantt chart for assigned tasks.
/// Existing green/red date marks are preserved, and self-created tasks are
/// deliberately excluded because they have no date fields in the PRD.
class CalendarPage extends StatefulWidget {
  final AppState app;
  final int initialMode; // 0 month, 1 week, 2 day, 3 gantt

  const CalendarPage({
    super.key,
    required this.app,
    this.initialMode = 0,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late int _mode;
  late Future<List<CalendarDay>> _days;
  late Future<List<TaskItem>> _receivedTasks;

  DateTime get _monthLast => DateTime(_month.year, _month.month + 1, 0);
  DateTime get _weekFirst => DateTime(_selected.year, _selected.month, _selected.day)
      .subtract(Duration(days: _selected.weekday - 1));
  DateTime get _rangeFirst => _mode == 1 ? _weekFirst : _mode == 2 ? _selected : _month;
  DateTime get _rangeLast => _mode == 1
      ? _weekFirst.add(const Duration(days: 6))
      : _mode == 2
          ? _selected
          : _monthLast;

  @override
  void initState() {
    super.initState();
    final now = chinaNow;
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
    // Gantt mode only needs the received task list. The backend calendar API
    // restricts date ranges to 31 days; never ask for a six-week grid here.
    _days = !allowed || _mode == 3
        ? Future.value(<CalendarDay>[])
        : widget.app.repo.calendar(dayString(_rangeFirst), dayString(_rangeLast));
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

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _days;
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
        appBar: AppBar(title: const Text('日历 · 任务甘特图')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
              children: [
                const PageHeading(
                  overline: 'YOUR TIMELINE',
                  title: '工作时间轴',
                  description: '日历标记与任务甘特图，让工作安排更清晰',
                ),
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
                      child: OutlinedButton.icon(
                        onPressed: () => _changeMode(3),
                        icon: const Icon(Icons.view_timeline_rounded, size: 18),
                        label: const Text('打开完整甘特图'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );

  Widget _controls() => SoftCard(
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
                  child: Text(
                    _periodText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.deep),
                  ),
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
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _changeMode(i),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == i ? Palette.primary : const Color(0xFFF1F6F3),
                            borderRadius: BorderRadius.circular(12),
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
                _Legend(color: Color(0xFFFBE4B9), label: '待开始'),
                _Legend(color: Color(0xFFE0DDF9), label: '进行中'),
                _Legend(color: Color(0xFFCFEEE0), label: '已完成'),
                _Legend(color: Palette.coral, label: '有日志'),
              ],
            ),
          ],
        ),
      );

  // The reference-inspired month view places pastel date-range bars directly
  // inside each week instead of repeating an independent chart below the grid.
  // Assigned-task spans are clipped by week and shown on collision-free lanes.
  Widget _calendarContents() => FutureBuilder<List<CalendarDay>>(
        future: _days,
        builder: (context, daySnapshot) {
          if (daySnapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (daySnapshot.hasError) {
            return ErrorPanel(
              error: daySnapshot.error!,
              onRetry: () => setState(_reload),
            );
          }
          final dayMap = <String, CalendarDay>{
            for (final day in daySnapshot.data ?? <CalendarDay>[])
              day.date: day,
          };
          return FutureBuilder<List<TaskItem>>(
            future: _receivedTasks,
            builder: (context, taskSnapshot) {
              final tasks = taskSnapshot.data ?? <TaskItem>[];
              if (_mode == 2) {
                return _dayView(dayMap[dayString(_selected)], tasks);
              }
              return _weeksView(
                dayMap,
                tasks,
                loading: taskSnapshot.connectionState != ConnectionState.done,
                taskError: taskSnapshot.hasError,
              );
            },
          );
        },
      );

  Widget _weeksView(
    Map<String, CalendarDay> dayMap,
    List<TaskItem> tasks, {
    required bool loading,
    required bool taskError,
  }) {
    final first = _mode == 0
        ? _month.subtract(Duration(days: _month.weekday - 1))
        : _weekFirst;
    final totalDays = _mode == 1
        ? 7
        : ((_monthLast.day + _month.weekday - 1 + 6) ~/ 7) * 7;
    final numberOfWeeks = totalDays ~/ 7;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final name in const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'])
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (taskError)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '任务暂时无法加载，日历日期仍可正常查看',
                style: TextStyle(color: Palette.coral, fontSize: 11),
              ),
            ),
          for (var weekIndex = 0; weekIndex < numberOfWeeks; weekIndex++)
            _weekRow(
              first.add(Duration(days: weekIndex * 7)),
              dayMap,
              tasks,
            ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          _dayInfo(dayMap[dayString(_selected)]),
          const SizedBox(height: 8),
          const Text(
            '彩色横条表示派发任务的起止日期，点击可查看详情',
            style: TextStyle(color: Palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weekRow(
    DateTime weekFirst,
    Map<String, CalendarDay> dayMap,
    List<TaskItem> tasks,
  ) {
    // Lane allocation prevents overlapping assignments from hiding each
    // other. Overflow is explicitly indicated rather than silently omitted.
    final spans = buildGanttSpans(
      tasks,
      weekFirst,
      weekFirst.add(const Duration(days: 6)),
    );
    final rows = <({GanttTaskSpan span, int lane})>[];
    final endByLane = <int>[];
    var hidden = 0;
    for (final span in spans) {
      var placed = false;
      for (var lane = 0; lane < 3; lane++) {
        if (lane >= endByLane.length) endByLane.add(-1);
        if (span.startColumn > endByLane[lane]) {
          rows.add((span: span, lane: lane));
          endByLane[lane] = span.startColumn + span.dayCount - 1;
          placed = true;
          break;
        }
      }
      if (!placed) hidden++;
    }
    final usedLanes = endByLane.length;
    final barsHeight = usedLanes == 0 ? 12.0 : usedLanes * 26.0 + 7.0;
    return Container(
      padding: const EdgeInsets.only(bottom: 9, top: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 43,
            child: Row(
              children: [
                for (var dayIndex = 0; dayIndex < 7; dayIndex++)
                  Expanded(
                    child: _dateCell(
                      weekFirst.add(Duration(days: dayIndex)),
                      dayMap,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
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
          if (hidden > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '还有 $hidden 项，请查看完整甘特图',
                  style: const TextStyle(fontSize: 10, color: Palette.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateCell(DateTime date, Map<String, CalendarDay> dayMap) {
    final isSelected = dayString(date) == dayString(_selected);
    final isToday = dayString(date) == todayChina;
    final sameMonth = _mode == 1 ||
        (date.year == _month.year && date.month == _month.month);
    final mark = dayMap[dayString(date)]?.mark;
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
          if (mark == 'RED')
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.coral,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayView(CalendarDay? day, List<TaskItem> tasks) {
    final todaySpans = buildGanttSpans(tasks, _selected, _selected);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dayInfo(day),
          if (todaySpans.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              '这一天进行的任务',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.deep),
            ),
            const SizedBox(height: 10),
            for (final span in todaySpans)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Material(
                  color: _barColor(span.task.status),
                  borderRadius: BorderRadius.circular(11),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    dense: true,
                    onTap: () => _showTaskDetails(span.task),
                    leading: const Icon(Icons.event_note_outlined, color: Palette.deep),
                    title: Text(span.task.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    subtitle: Text(span.task.statusLabel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _barColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFFCFEEE0);
      case 'IN_PROGRESS':
        return const Color(0xFFE0DDF9);
      default:
        return const Color(0xFFFBE4B9);
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

  Widget _dayInfo(CalendarDay? day) {
    final selected = dayString(_selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selected.month}月${_selected.day}日 · 工作安排',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.deep),
        ),
        const SizedBox(height: 11),
        if (day == null || (day.logCount == 0 && day.taskCount == 0))
          const EmptyPanel(
            title: '这一天很清爽',
            subtitle: '暂无日志和派发任务',
            icon: Icons.event_available_outlined,
          )
        else ...[
          if (day.taskCount > 0)
            _eventRow(Icons.task_alt_rounded, Palette.primary,
                '派发任务', '${day.taskCount} 项任务覆盖这一天'),
          if (day.logCount > 0)
            _eventRow(Icons.auto_stories_rounded, Palette.coral,
                '工作日志', '${day.logCount} 篇日志记录'),
        ],
        const SizedBox(height: 8),
        Text(
          '日期 $selected · 仅统计你有权限查看的内容',
          style: const TextStyle(color: Palette.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _eventRow(IconData icon, Color color, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Palette.divider),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.deep)),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: Palette.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
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
