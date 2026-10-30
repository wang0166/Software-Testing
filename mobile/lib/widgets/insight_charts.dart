import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/insight_metrics.dart';
import '../core/models.dart';
import '../core/theme.dart';

class InsightChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const InsightChartCard({super.key, required this.title,
    required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 15)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(
        color: Palette.muted, fontSize: 11, height: 1.4)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

/// Real completion counts. In-progress tasks with no progress field display
/// "进行中" rather than making up a percentage.
class TaskCompletionTable extends StatelessWidget {
  final List<TaskItem> received;
  final List<DispatchedTask> dispatched;
  const TaskCompletionTable({super.key,
    required this.received, required this.dispatched});

  @override
  Widget build(BuildContext context) {
    final rows = <_CompletionRow>[
      ...dispatched.map((task) => _CompletionRow(
        task.name,
        task.assigneeCount == 0
          ? '无成员数据'
          : '${task.completedCount}/${task.assigneeCount} 人',
        completionRatio(task),
      )),
      ...received.map((task) => _CompletionRow(
        task.name,
        task.statusLabel,
        task.status == 'COMPLETED' ? 1.0
          : task.status == 'NOT_STARTED' ? 0.0 : null,
      )),
    ];
    if (rows.isEmpty) return const Text('暂无授权任务数据',
      style: TextStyle(color: Palette.muted, fontSize: 12));
    return Column(children: [
      Container(
        color: const Color(0xFFE9EFF3),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: const Row(children: [
          Expanded(flex: 5, child: Text('任务名称', style: TextStyle(fontSize: 11,
            color: Palette.deep, fontWeight: FontWeight.w900))),
          Expanded(flex: 3, child: Text('完成情况', style: TextStyle(fontSize: 11,
            color: Palette.deep, fontWeight: FontWeight.w900))),
          Expanded(flex: 2, child: Text('完成率', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: Palette.deep,
              fontWeight: FontWeight.w900))),
        ]),
      ),
      ...rows.take(12).map((row) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom:
          BorderSide(color: Palette.divider, width: .6))),
        child: Row(children: [
          Expanded(flex: 5, child: Text(row.name,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Palette.deep))),
          Expanded(flex: 3, child: Text(row.status,
            style: const TextStyle(fontSize: 10, color: Palette.muted))),
          Expanded(flex: 2, child: Text(row.ratio == null ? '—' :
            '${(row.ratio! * 100).round()}%', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: row.ratio == 1 ? Palette.primary : Palette.deep))),
        ]),
      )),
      if (rows.length > 12) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('仅预览前12条，共 ${rows.length} 条任务',
          style: const TextStyle(color: Palette.muted, fontSize: 11)),
      ),
    ]);
  }
}

class _CompletionRow {
  final String name;
  final String status;
  final double? ratio;
  const _CompletionRow(this.name, this.status, this.ratio);
}

/// Urgency proportions from authorized *received* tasks, not synthetic data.
class TaskUrgencyPie extends StatelessWidget {
  final List<TaskItem> tasks;
  const TaskUrgencyPie({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final urgent = urgentTaskCount(tasks);
    final total = tasks.length;
    final normal = total - urgent;
    return Row(children: [
      SizedBox(
        width: 112,
        height: 112,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            key: const Key('task_urgency_pie'),
            painter: _UrgencyPainter(urgent: urgent, total: total),
            size: const Size(112, 112),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(total == 0 ? '—' : '${(urgent / total * 100).round()}%',
              style: const TextStyle(color: Palette.deep,
                fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('紧急占比', style: TextStyle(
              color: Palette.muted, fontSize: 10)),
          ]),
        ]),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend(const Color(0xFFD97754), '紧急任务', urgent),
          const SizedBox(height: 12),
          _legend(Palette.primary, '普通任务', normal),
          const SizedBox(height: 12),
          Text('总计 $total 项', style: const TextStyle(
            color: Palette.muted, fontSize: 11)),
        ],
      )),
    ]);
  }

  Widget _legend(Color color, String title, int count) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: const TextStyle(
      color: Palette.deep, fontSize: 12))),
    Text('$count', style: const TextStyle(
      fontWeight: FontWeight.w900, color: Palette.deep)),
  ]);
}

class _UrgencyPainter extends CustomPainter {
  final int urgent;
  final int total;
  const _UrgencyPainter({required this.urgent, required this.total});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bounds = rect.deflate(9);
    final base = Paint()..color = const Color(0xFFE6EBEF)
      ..strokeWidth = 15..style = PaintingStyle.stroke;
    canvas.drawArc(bounds, 0, 2 * math.pi, false, base);
    if (total == 0) return;
    final urgentSweep = 2 * math.pi * urgent / total;
    final normalSweep = 2 * math.pi - urgentSweep;
    final urgentPaint = Paint()..color = const Color(0xFFD97754)
      ..strokeWidth = 15..style = PaintingStyle.stroke;
    final regularPaint = Paint()..color = Palette.primary
      ..strokeWidth = 15..style = PaintingStyle.stroke;
    if (normalSweep > 0) {
      canvas.drawArc(bounds, -math.pi / 2, normalSweep, false, regularPaint);
    }
    if (urgentSweep > 0) {
      canvas.drawArc(bounds, -math.pi / 2 + normalSweep,
        urgentSweep, false, urgentPaint);
    }
  }
  @override
  bool shouldRepaint(covariant _UrgencyPainter old) =>
    old.urgent != urgent || old.total != total;
}

class TaskStatusBarChart extends StatelessWidget {
  final List<TaskItem> tasks;
  const TaskStatusBarChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final counts = countTaskStatuses(tasks);
    final maxValue = math.max(1, math.max(counts.notStarted,
      math.max(counts.inProgress, counts.completed)));
    return SizedBox(
      height: 160,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _bar('待开始', counts.notStarted, maxValue, const Color(0xFFB6C2CF)),
        const SizedBox(width: 12),
        _bar('进行中', counts.inProgress, maxValue, const Color(0xFF328C9B)),
        const SizedBox(width: 12),
        _bar('已完成', counts.completed, maxValue, Palette.primary),
      ]),
    );
  }

  Widget _bar(String label, int count, int max, Color color) => Expanded(
    child: Column(children: [
      Text('$count', style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w900, color: Palette.deep)),
      const SizedBox(height: 6),
      Expanded(child: Align(alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: count == 0 ? .025 : count / max,
          widthFactor: .65,
          child: DecoratedBox(decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          )),
        ),
      )),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(
        fontSize: 11, color: Palette.muted)),
    ]),
  );
}

class WorkKeywordPanel extends StatelessWidget {
  final List<KeywordScore> keywords;
  const WorkKeywordPanel({super.key, required this.keywords});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (keywords.isEmpty)
        const Text('当前授权数据中未提取到匹配的工作关键词',
          style: TextStyle(color: Palette.muted, fontSize: 12))
      else
        ...keywords.map((word) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 58, child: Text(word.term, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: Palette.deep))),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (word.score / keywords.first.score).clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                color: Palette.primary,
                backgroundColor: const Color(0xFFE8EDF1),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 75, child: Text('${word.occurrences}次 / ${word.score}分',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Palette.deep, fontSize: 10))),
          ]),
        )),
      const SizedBox(height: 10),
      const Text('统计规则：日志每次出现计1分，普通任务计2分，紧急任务计3分；'
        '仅在本机处理当前账号有权限读取的文本，不代表 AI 推断。',
        style: TextStyle(color: Palette.muted, fontSize: 10, height: 1.5)),
    ],
  );
}
