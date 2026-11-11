import 'package:flutter/material.dart';
import '../core/gantt_utils.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/holiday_calendar.dart';
import '../data/holiday_calendar_service.dart';
import '../core/theme.dart';
import '../widgets/task_gantt_chart.dart';
import '../widgets/ui.dart';
import '../widgets/redesign.dart';
import '../widgets/business.dart';
import '../widgets/holiday_calendar_widgets.dart';

/// Month/week/day task calendar and full Gantt view.
/// As required by the client, calendar views never request or display log data.
/// Task titles and overflow counts come only from authorized received tasks.
class CalendarPage extends StatefulWidget {
  final AppState app;
  final int initialMode; // 0 month, 1 week, 2 day, 3 gantt
  final DateTime? initialDate;
  final bool embedded;
  final ValueChanged<int>? onTaskViewed;
  final HolidayCalendarService? holidayService;

  const CalendarPage({
    super.key,
    required this.app,
    this.initialMode = 0,
    this.initialDate,
    this.embedded = false,
    this.onTaskViewed,
    this.holidayService,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;
  late int _mode;
  late Future<List<TaskItem>> _receivedTasks;
  late Future<HolidayCalendarView> _holidayViewFuture;

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

  void _loadHolidays({bool forceRefresh = false}) {
    final rangeStart = _mode == 1 ? _weekFirst
        : _mode == 2 ? _selected
        : _month.subtract(Duration(days: _month.weekday - 1));
    final rangeEnd = _mode == 1 || _mode == 2
        ? _rangeLast
        : _monthLast.add(Duration(days: 7 - _monthLast.weekday));
    _holidayViewFuture = (widget.holidayService ?? widget.app.holidays).loadRange(
      rangeStart, rangeEnd, forceRefresh: forceRefresh);
  }

  void _reload() {
    _loadHolidays();
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
    setState(() {
      _reload();
      _loadHolidays(forceRefresh: true);
    });
    try {
      await Future.wait([_receivedTasks, _holidayViewFuture]);
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
                  _holidayAwareContents()
                else ...[
                  _holidayAwareContents(),
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
                _Legend(color: Color(0xFFC7D9EC), label: '进行中'),
                _Legend(color: Color(0xFFC7E5DD), label: '已完成'),
                Text('休 / 班 · 法定调休', style: TextStyle(
                  color: Palette.muted, fontSize: 10)),
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
  Widget _holidayAwareContents() => FutureBuilder<HolidayCalendarView>(
        future: _holidayViewFuture,
        builder: (context, snapshot) {
          final holidayView = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HolidaySyncNotice(
                view: holidayView,
                retry: () => setState(() => _loadHolidays(forceRefresh: true)),
              ),
              if (_mode == 3)
                _taskChart(full: true)
              else
                _calendarContents(holidayView),
            ],
          );
        },
      );

  Widget _calendarContents(HolidayCalendarView? holidays) => FutureBuilder<List<TaskItem>>(
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
          return _mode == 2 ? _dayView(tasks, holidays) : _weeksView(tasks, holidays);
        },
      );

  // 以独立页面打开完整甘特图，而不是把月历直接替换掉。
  void _openFullGantt() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => CalendarPage(
        app: widget.app, initialMode: 3, initialDate: _selected,
        onTaskViewed: widget.onTaskViewed,
        holidayService: widget.holidayService),
    ));
  }

  Widget _weeksView(List<TaskItem> tasks, HolidayCalendarView? holidays) {
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
            _weekRow(first.add(Duration(days: weekIndex * 7)), tasks, holidays),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          _dayInfo(tasks, holidays),
          const SizedBox(height: 8),
          const Text(
            '每日期最多显示两项任务，+数字表示未展示的任务数，点击可查看甘特图',
            style: TextStyle(color: Palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // iOS-like month grid: show two task titles in each day, then +N.
  // The calendar never has an independent vertical task scrollbar.
  Widget _weekRow(DateTime weekFirst, List<TaskItem> tasks,
      HolidayCalendarView? holidays) => Container(
    padding: const EdgeInsets.symmetric(vertical: 5),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Palette.divider)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 7; i++)
        Expanded(child: _dateCell(weekFirst.add(Duration(days: i)), tasks, holidays)),
    ]),
  );

  Widget _dateCell(DateTime date, List<TaskItem> tasks,
      HolidayCalendarView? holidays) {
    final key = dayString(date);
    final holiday = holidays?.on(date);
    final selected = key == dayString(_selected);
    final today = key == todayChina;
    final inMonth = _mode == 1 ||
      (date.year == _month.year && date.month == _month.month);
    final matches = buildGanttSpans(tasks, date, date)
      .map((span) => span.task).toList();
    const visibleLimit = 2;
    final remaining = matches.length - visibleLimit;
    return InkWell(
      key: ValueKey('calendar_day_$key'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        final changedMonth = _month.year != date.year || _month.month != date.month;
        _selected = date;
        _month = DateTime(date.year, date.month);
        if (changedMonth) _reload();
      }),
      child: Container(
        // Content determines the actual row height. A fixed 94px cell could
        // overflow when two task labels and the +N indicator were visible.
        // Keep a consistent minimum for empty days while allowing the whole
        // month page (not an inner cell) to scroll at larger text scales.
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F7FA) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          SizedBox(height: 26, child: Stack(children: [
            Center(child: Container(
              width: 26, height: 26, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Palette.primary
                    : today ? Palette.sage : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text('${date.day}', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: selected ? Colors.white
                  : inMonth ? Palette.deep : Palette.muted,
              )),
            )),
            if (inMonth && holiday?.dayTypeLabel.isNotEmpty == true)
              Positioned(right: 0, top: 0,
                child: HolidayDayBadge(day: holiday)),
          ])),
          if (inMonth && holiday != null && holiday.festivalLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: HolidayFestivalLabel(day: holiday),
            ),
          const SizedBox(height: 4),
          for (final task in matches.take(visibleLimit))
            Padding(padding: const EdgeInsets.only(bottom: 3), child: Material(
              color: _barColor(task.status),
              borderRadius: BorderRadius.circular(3),
              child: InkWell(
                onTap: () => _showTaskDetails(task),
                child: Padding(padding: const EdgeInsets.symmetric(
                    horizontal: 3, vertical: 3), child: Text(
                  task.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: _barInk(task.status)),
                )),
              ),
            )),
          if (remaining > 0)
            InkWell(
              key: Key('calendar_more_$key'),
              onTap: _openFullGantt,
              child: Text('+$remaining', textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.primary,
                  fontSize: 11, fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
    );
  }

  Widget _dayView(List<TaskItem> tasks, HolidayCalendarView? holidays) {
    final todaySpans = buildGanttSpans(tasks, _selected, _selected);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dayInfo(tasks, holidays),
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
                child: _dayTaskTile(span.task),
              ),
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
      subtitle: Text(task.status == 'COMPLETED' ? '已完成' : '进行中'),
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
        return const Color(0xFFC7D9EC);
    }
  }

  Color _barInk(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF25684A);
      case 'IN_PROGRESS':
        return const Color(0xFF53477E);
      default:
        return const Color(0xFF53477E);
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
    widget.onTaskViewed?.call(task.id);
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

  Widget _dayInfo(List<TaskItem> tasks, HolidayCalendarView? holidays) {
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
        if (holidays?.on(_selected) != null) ...[
          const SizedBox(height: 6),
          SelectedHolidayInfo(day: holidays!.on(_selected)),
        ],
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
