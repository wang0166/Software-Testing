import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/gantt_utils.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'ui.dart';

/// Scrollable task Gantt chart with a fixed task-name column and date columns.
/// Green bars represent occupied dates, NOT progress or urgency.
class TaskGanttChart extends StatefulWidget {
  final List<TaskItem> tasks;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime selectedDate;
  final bool full;
  final ValueChanged<TaskItem> onTaskTap;

  const TaskGanttChart({
    super.key,
    required this.tasks,
    required this.rangeStart,
    required this.rangeEnd,
    required this.selectedDate,
    required this.onTaskTap,
    this.full = false,
  });

  @override
  State<TaskGanttChart> createState() => _TaskGanttChartState();
}

class _TaskGanttChartState extends State<TaskGanttChart> {
  static const double _columnWidth = 35;
  static const double _rowHeight = 58;
  static const double _labelWidth = 123;
  static const double _headerHeight = 48;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelectedDate());
  }

  @override
  void didUpdateWidget(covariant TaskGanttChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (dayString(oldWidget.rangeStart) != dayString(widget.rangeStart) ||
        dayString(oldWidget.selectedDate) != dayString(widget.selectedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelectedDate());
    }
  }

  void _focusSelectedDate() {
    if (!mounted || !_scrollController.hasClients) return;
    final offset = ganttDateOnly(widget.selectedDate)
        .difference(ganttDateOnly(widget.rangeStart))
        .inDays;
    final desired = math.max(0.0, (offset - 2) * _columnWidth);
    _scrollController.jumpTo(
      desired.clamp(0.0, _scrollController.position.maxScrollExtent).toDouble(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = ganttDateOnly(widget.rangeStart);
    final end = ganttDateOnly(widget.rangeEnd);
    final totalDays = end.difference(start).inDays + 1;
    final spans = buildGanttSpans(widget.tasks, start, end);
    if (totalDays <= 0) return const SizedBox.shrink();

    if (spans.isEmpty) {
      return const SoftCard(
        child: EmptyPanel(
          title: '这个时间段暂无派发任务',
          subtitle: '有开始日期和截止日期的接收任务，会显示为横向时间条',
          icon: Icons.view_timeline_outlined,
        ),
      );
    }
    final visibleSpans = widget.full ? spans : spans.take(4).toList();
    final width = totalDays * _columnWidth;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(13, 16, 13, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_timeline_rounded, color: Palette.primary, size: 20),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('任务时间甘特图',
                    style: TextStyle(color: Palette.deep, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Palette.sage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${spans.length} 项',
                    style: const TextStyle(color: Palette.primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text('横向滑动看日期 · 点击任务条查看详情',
              style: TextStyle(fontSize: 11, color: Palette.muted)),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _labelWidth,
                child: Column(
                  children: [
                    Container(
                      height: _headerHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 4),
                      child: const Text('任务名称',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Palette.deep)),
                    ),
                    for (final span in visibleSpans) _label(span.task),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _headerHeight,
                          child: Row(
                            children: [
                              for (var i = 0; i < totalDays; i++)
                                _dateHeader(start.add(Duration(days: i))),
                            ],
                          ),
                        ),
                        for (final span in visibleSpans)
                          _timelineRow(start, totalDays, width, span),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!widget.full && spans.length > visibleSpans.length) ...[
            const SizedBox(height: 11),
            Text('还有 ${spans.length - visibleSpans.length} 项，点击上方“甘特图”可查看完整列表',
                style: const TextStyle(fontSize: 11, color: Palette.muted)),
          ],
          if (spans.any((s) => s.inferredStart)) ...[
            const SizedBox(height: 10),
            const Text('注：部分旧演示任务缺少开始日期，仅在截止当天显示。',
                style: TextStyle(fontSize: 11, color: Palette.muted)),
          ],
          const SizedBox(height: 11),
          const Row(
            children: [
              Icon(Icons.circle, color: Palette.primary, size: 11),
              SizedBox(width: 6),
              Expanded(
                child: Text('绿色只表示任务日期占用，不代表完成进度或紧急程度',
                    style: TextStyle(color: Palette.muted, fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(TaskItem task) => InkWell(
        onTap: () => widget.onTaskTap(task),
        child: Container(
          height: _rowHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Palette.divider)),
          ),
          padding: const EdgeInsets.only(left: 4, right: 8, top: 5, bottom: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Palette.deep, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(task.statusLabel,
                  style: const TextStyle(color: Palette.muted, fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _dateHeader(DateTime date) {
    final isToday = dayString(date) == todayChina;
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      height: _headerHeight,
      width: _columnWidth,
      decoration: BoxDecoration(
        color: isToday ? Palette.sage :
            date.weekday >= 6 ? const Color(0xFFFFF8EE) : const Color(0xFFF7FAF8),
        border: const Border(right: BorderSide(color: Palette.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${date.day}',
              style: TextStyle(color: isToday ? Palette.primary : Palette.deep,
                  fontSize: 12, fontWeight: FontWeight.w800)),
          Text('周${weekdays[date.weekday - 1]}',
              style: const TextStyle(color: Palette.muted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _timelineRow(DateTime start, int count, double width, GanttTaskSpan span) {
    final barWidth = span.dayCount * _columnWidth;
    return SizedBox(
      height: _rowHeight,
      width: width,
      child: Stack(
        children: [
          Row(
            children: [
              for (var index = 0; index < count; index++)
                Container(
                  width: _columnWidth,
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    color: dayString(start.add(Duration(days: index))) == todayChina
                        ? Palette.sage.withValues(alpha: .55)
                        : index.isOdd ? const Color(0xFFFAFCFB) : Colors.white,
                    border: const Border(
                      right: BorderSide(color: Palette.divider),
                      bottom: BorderSide(color: Palette.divider),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: span.startColumn * _columnWidth + 3,
            top: 16,
            width: barWidth - 6,
            height: 27,
            child: Material(
              color: Palette.primary,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: ValueKey('gantt_task_${span.task.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onTaskTap(span.task),
                child: barWidth >= 90
                    ? const Center(
                        child: Text('任务周期',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
