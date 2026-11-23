import 'models.dart';

/// Normalizes a calendar date to UTC midnight so DST changes do not alter
/// the number of displayed date columns.
DateTime ganttDateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Accepts legacy date-only and new minute-precision task timestamps.
DateTime? parseGanttDate(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ].*)?$').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

class GanttTaskSpan {
  final TaskItem task;
  final DateTime start;
  final DateTime end;
  final int startColumn;
  final int dayCount;
  final bool inferredStart;

  const GanttTaskSpan({
    required this.task,
    required this.start,
    required this.end,
    required this.startColumn,
    required this.dayCount,
    required this.inferredStart,
  });
}

/// Only received/assigned tasks are shown in the calendar. Personal tasks
/// have no dates by contract. Both start and deadline are inclusive.
/// When old demo records omit startDate, show only the deadline day instead
/// of fabricating a multi-day duration.
List<GanttTaskSpan> buildGanttSpans(
  Iterable<TaskItem> tasks,
  DateTime visibleStart,
  DateTime visibleEnd,
) {
  final from = ganttDateOnly(visibleStart);
  final to = ganttDateOnly(visibleEnd);
  if (to.isBefore(from)) return [];
  final result = <GanttTaskSpan>[];
  for (final task in tasks) {
    if (task.source != 'RECEIVED') continue;
    final deadline = parseGanttDate(task.deadline);
    if (deadline == null) continue;
    final realStart = parseGanttDate(task.startDate);
    final start = realStart ?? deadline;
    if (deadline.isBefore(start) || start.isAfter(to) || deadline.isBefore(from)) {
      continue;
    }
    final clippedStart = start.isBefore(from) ? from : start;
    final clippedEnd = deadline.isAfter(to) ? to : deadline;
    result.add(GanttTaskSpan(
      task: task,
      start: start,
      end: deadline,
      startColumn: clippedStart.difference(from).inDays,
      dayCount: clippedEnd.difference(clippedStart).inDays + 1,
      inferredStart: realStart == null,
    ));
  }
  result.sort((a, b) {
    final order = a.start.compareTo(b.start);
    return order != 0 ? order : a.end.compareTo(b.end);
  });
  return result;
}


/// Assign every weekly task span to a non-overlapping display lane.
///
/// Previously, the calendar discarded spans that needed a fourth lane.
/// Keeping all lanes lets the week-row viewport scroll vertically without
/// losing tasks or interfering with the full Gantt navigation.
List<({GanttTaskSpan span, int lane})> allocateGanttLanes(
    Iterable<GanttTaskSpan> spans) {
  final endByLane = <int>[];
  final rows = <({GanttTaskSpan span, int lane})>[];
  for (final span in spans) {
    var lane = 0;
    while (lane < endByLane.length &&
        span.startColumn <= endByLane[lane]) {
      lane++;
    }
    if (lane == endByLane.length) endByLane.add(-1);
    rows.add((span: span, lane: lane));
    endByLane[lane] = span.startColumn + span.dayCount - 1;
  }
  return rows;
}
