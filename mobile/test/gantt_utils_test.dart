import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/gantt_utils.dart';
import 'package:mobile/core/models.dart';

TaskItem received(String name, String? from, String? to, {int id = 1}) =>
    TaskItem(
      id: id,
      name: name,
      details: '测试任务',
      status: 'IN_PROGRESS',
      source: 'RECEIVED',
      startDate: from,
      deadline: to,
    );

void main() {
  test('跨月份任务裁剪到当前月，开始和截止日期都包含', () {
    final spans = buildGanttSpans(
      [received('跨月任务', '2026-09-29', '2026-10-03')],
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 31),
    );
    expect(spans, hasLength(1));
    expect(spans.first.startColumn, 0);
    expect(spans.first.dayCount, 3);
  });

  test('结束超出当前月的任务，只显示当月日期', () {
    final span = buildGanttSpans(
      [received('下月结束', '2026-10-30', '2026-11-05')],
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 31),
    ).single;
    expect(span.startColumn, 29);
    expect(span.dayCount, 2);
  });

  test('一天任务占一格，不会变成零宽度', () {
    final span = buildGanttSpans(
      [received('单日任务', '2026-10-21', '2026-10-21')],
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 31),
    ).single;
    expect(span.startColumn, 20);
    expect(span.dayCount, 1);
  });

  test('个人任务、不合法日期及范围外任务不出现在甘特图', () {
    final tasks = [
      TaskItem(
        id: 9, name: '我的自建任务', details: '', status: 'NOT_STARTED',
        source: 'PERSONAL', startDate: '2026-10-01', deadline: '2026-10-10',
      ),
      received('日期倒置', '2026-10-12', '2026-10-10', id: 2),
      received('范围外', '2026-09-01', '2026-09-30', id: 3),
      received('日期无效', '2026-10-99', '2026-10-99', id: 4),
    ];
    final spans = buildGanttSpans(
      tasks, DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 31));
    expect(spans, isEmpty);
  });

  test('缺少开始日期的旧 Mock 接收任务只显示截止日', () {
    final span = buildGanttSpans(
      [received('旧数据', null, '2026-10-12')],
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 31),
    ).single;
    expect(span.startColumn, 11);
    expect(span.dayCount, 1);
    expect(span.inferredStart, isTrue);
  });

  test('分钟级任务时间仍能进入甘特图', () {
    final spans = buildGanttSpans([
      received('精确任务', '2026-10-21T09:30:00', '2026-10-22T17:45:00')
    ], DateTime.utc(2026,10,1), DateTime.utc(2026,10,31));
    expect(spans.single.startColumn, 20);
    expect(spans.single.dayCount, 2);
  });

  test('跨夏令时边界仍按日历天数计算', () {
    final span = buildGanttSpans(
      [received('跨月时区', '2026-10-31', '2026-11-03')],
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 30),
    ).single;
    expect(span.startColumn, 0);
    expect(span.dayCount, 3);
  });
}

// Minute-precision timestamps are normalized to calendar days for Gantt spans.
