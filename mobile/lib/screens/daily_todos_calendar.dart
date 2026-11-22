import 'dart:async';
import 'dart:collection' show IterableExtensions;

import 'package:flutter/material.dart';
import '../core/daily_todos.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/repository.dart';

/// The user's private month-view todo calendar. No company-task or log APIs.
/// 传入 [repo] 时读写云端 `/api/daily-items`；为空时退回本地存储（离线与组件测试）。
class DailyTodosCalendar extends StatefulWidget {
  final int userId;
  final PandoraRepository? repo;
  const DailyTodosCalendar({super.key, required this.userId, this.repo});
  @override
  State<DailyTodosCalendar> createState() => _DailyTodosCalendarState();
}

class _DailyTodosCalendarState extends State<DailyTodosCalendar> {
  late DateTime _selected;
  late DateTime _month;
  List<DailyTodo> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  int _loadRevision = 0;
  double _swipeDistance = 0;
  Timer? _monthTurnTimer;
  int? _hoverDirection;
  DailyTodo? _draggedItem;
  DateTime? _dragMonth, _dragDay, _dragAnchor;
  List<DailyTodo> _dragItems = const [];

  static final _firstDate = DateTime(1);
  static final _lastDate = DateTime(9999, 12, 31);

  DailyTodoStorage get _storage => DailyTodoStorage(widget.userId);

  @override
  void initState() {
    super.initState();
    final today = chinaNow;
    _selected = DateTime(today.year, today.month, today.day);
    _month = DateTime(today.year, today.month);
    _reload();
  }

  @override
  void didUpdateWidget(covariant DailyTodosCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.repo != widget.repo) {
      _finishDrag();
      _items = [];
      _reload();
    }
  }

  @override
  void dispose() {
    _monthTurnTimer?.cancel();
    super.dispose();
  }

  int _weeks(DateTime month) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return ((month.weekday - 1 + days + 6) ~/ 7).clamp(4, 6).toInt();
  }

  DateTime _gridStart(DateTime month) =>
    DateTime(month.year, month.month, 2 - month.weekday);

  Future<void> _reload() async {
    final revision = ++_loadRevision;
    final repo = widget.repo;
    final month = _month;
    final lastDay = DateTime(month.year, month.month + 1, 0);
    setState(() { _loading = true; _loadError = null; });
    try {
      final items = repo == null ? await _storage.read() : await repo.dailyItems(
        from: dayString(month), to: dayString(lastDay),
      );
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || revision != _loadRevision) return;
      setState(() { _loadError = '$e'; _loading = false; });
    }
  }

  bool _moveMonth(int delta) {
    final newMonth = DateTime(_month.year, _month.month + delta);
    if (newMonth.isBefore(_firstDate) || newMonth.isAfter(_lastDate)) return false;
    final days = DateUtils.getDaysInMonth(newMonth.year, newMonth.month);
    _selectDate(DateTime(newMonth.year, newMonth.month,
      _selected.day.clamp(1, days).toInt()));
    return true;
  }

  void _selectDate(DateTime date) {
    final month = DateTime(date.year, date.month);
    final changedMonth = month != _month;
    setState(() {
      _month = month;
      _selected = date;
    });
    if (changedMonth && widget.repo != null) _reload();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context, initialDate: _selected,
      firstDate: _firstDate, lastDate: _lastDate,
      helpText: '选择每日事项日期',
    );
    if (date != null && mounted) _selectDate(date);
  }

  List<DailyTodo> _itemsFor(DateTime date, List<DailyTodo> items) {
    final day = dayString(date);
    return items.where((item) => item.overlaps(from: day, to: day)).toList();
  }

  void _startDrag(DailyTodo item, DateTime anchor) {
    setState(() {
      _draggedItem = item;
      _dragMonth = _month;
      _dragDay = _selected;
      _dragAnchor = anchor;
      _dragItems = _items;
    });
  }

  void _finishDrag() {
    _stopMonthTurn();
    if (!mounted) return;
    setState(() {
      _draggedItem = null;
      _dragMonth = null;
      _dragDay = null;
      _dragAnchor = null;
      _dragItems = const [];
    });
  }

  void _startMonthTurn(int delta) {
    if (_hoverDirection == delta) return;
    _stopMonthTurn();
    _hoverDirection = delta;
    _monthTurnTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || !_moveMonth(delta)) _stopMonthTurn();
    });
  }

  void _stopMonthTurn([int? delta]) {
    if (delta != null && delta != _hoverDirection) return;
    _monthTurnTimer?.cancel();
    _monthTurnTimer = null;
    _hoverDirection = null;
  }

  Widget _monthDragTarget(int delta, Widget child, {Key? key}) => DragTarget<String>(
    key: key,
    onWillAcceptWithDetails: (details) {
      if (_draggedItem?.id != details.data) return false;
      _startMonthTurn(delta);
      return true;
    },
    onLeave: (_) => _stopMonthTurn(delta),
    onAcceptWithDetails: (_) => _stopMonthTurn(delta),
    builder: (context, hovering, rejected) => ColoredBox(
      color: hovering.isEmpty ? Colors.transparent : Palette.sage,
      child: child,
    ),
  );

  Widget _draggable(DailyTodo item, DateTime anchor, String location, Widget child) =>
    LongPressDraggable<String>(
      key: Key('daily_todo_drag_${location}_${item.id}'),
      data: item.id,
      maxSimultaneousDrags: _saving || _loading || _loadError != null ||
        _draggedItem != null || !item.hasValidRange ? 0 : 1,
      rootOverlay: true,
      onDragStarted: () => _startDrag(item, anchor),
      onDragCompleted: _finishDrag,
      onDraggableCanceled: (_, __) => _finishDrag(),
      feedback: Material(
        color: Palette.primary, borderRadius: BorderRadius.circular(6),
        elevation: 4, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(item.title, style: const TextStyle(color: Colors.white)),
        ),
      ),
      child: child,
    );

  Future<void> _dropOnDate(String id, DateTime date) async {
    _stopMonthTurn();
    final item = _draggedItem?.id == id ? _draggedItem
      : _items.where((item) => item.id == id).firstOrNull;
    if (item == null || !item.hasValidRange || _saving) return;
    final anchor = _draggedItem?.id == id ? _dragAnchor : null;
    final moved = item.moveTo(dayString(date), fromDate: anchor == null ? null : dayString(anchor));
    if (!moved.hasValidRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('移动后的事项日期超出支持范围')),
      );
      return;
    }
    _selectDate(date);
    if (moved.date != item.date) await _persist(moved);
  }

  /// 云端模式按单条增删改落库；本地模式继续整表写入 SharedPreferences。
  Future<void> _persist(DailyTodo draft) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = widget.repo;
      if (repo == null) {
        final stored = draft.id.isEmpty
          ? draft.copyWith(id: '${DateTime.now().microsecondsSinceEpoch}')
          : draft;
        final updated = [..._items]..removeWhere((e) => e.id == stored.id);
        updated.add(stored);
        await _storage.write(updated);
        _items = updated;
      } else {
        final saved = draft.id.isEmpty
          ? await repo.createDailyItem(date: draft.date, title: draft.title,
              note: draft.note, completed: draft.completed, endDate: draft.endDate,
              startTime: draft.startTime, endTime: draft.endTime)
          : await repo.updateDailyItem(draft);
        _items = [
          ..._items.where((e) => e.id != draft.id && e.id != saved.id),
          saved,
        ];
      }
      if (mounted) {
        if (repo == null) {
          setState(() {});
        } else {
          await _reload();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存每日事项失败：$error')),
        );
        if (widget.repo != null) await _reload();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(DailyTodo item) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = widget.repo;
      if (repo == null) {
        final updated = _items.where((e) => e.id != item.id).toList();
        await _storage.write(updated);
        _items = updated;
      } else {
        await repo.deleteDailyItem(item.id);
        _items = _items.where((e) => e.id != item.id).toList();
      }
      if (mounted) {
        if (repo == null) {
          setState(() {});
        } else {
          await _reload();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除每日事项失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _edit([DailyTodo? item]) async {
    var draftTitle = item?.title ?? '';
    var draftNote = item?.note ?? '';
    var start = item == null ? _selected : DateTime.tryParse(item.date) ?? _selected;
    var end = item == null ? _selected : DateTime.tryParse(item.endDate) ?? start;
    var startTime = item?.hasValidRange == true ? item?.startTime : null;
    var endTime = item?.hasValidRange == true ? item?.endTime : null;
    String? errorText;
    final result = await showDialog<DailyTodo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chooseDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: isStart ? start : end,
              firstDate: _firstDate, lastDate: _lastDate,
              helpText: isStart ? '选择开始日期' : '选择结束日期',
            );
            if (picked == null || !context.mounted) return;
            setDialogState(() {
              if (isStart) {
                if (start == end || picked.isAfter(end)) end = picked;
                start = picked;
              } else {
                end = picked;
              }
              errorText = null;
            });
          }

          Future<void> chooseTime(bool isStart) async {
            final current = isStart ? startTime : endTime;
            final parts = current?.split(':');
            final now = chinaNow;
            final picked = await showTimePicker(
              context: context,
              initialTime: parts == null ? TimeOfDay(hour: now.hour, minute: now.minute)
                : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
              helpText: isStart ? '选择开始时间' : '选择结束时间',
            );
            if (picked == null || !context.mounted) return;
            final hour = picked.hour.toString().padLeft(2, '0');
            final minute = picked.minute.toString().padLeft(2, '0');
            setDialogState(() {
              if (isStart) {
                startTime = '$hour:$minute';
              } else {
                endTime = '$hour:$minute';
              }
              errorText = null;
            });
          }

          return AlertDialog(
            title: Text(item == null ? '新增个人事项' : '编辑个人事项'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  key: const Key('daily_todo_title_input'), initialValue: draftTitle,
                  onChanged: (value) => draftTitle = value,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '事项名称'),
                ),
                _rangeField('开始日期', dayString(start), Icons.calendar_today,
                  const Key('daily_todo_start_date'), () => chooseDate(true)),
                _rangeField('结束日期', dayString(end), Icons.calendar_today,
                  const Key('daily_todo_end_date'), () => chooseDate(false)),
                _rangeField('开始时间', startTime ?? '全天', Icons.schedule,
                  const Key('daily_todo_start_time'), () => chooseTime(true)),
                _rangeField('结束时间', endTime ?? '全天', Icons.schedule,
                  const Key('daily_todo_end_time'), () => chooseTime(false)),
                if (startTime != null || endTime != null)
                  TextButton(onPressed: () => setDialogState(() {
                    startTime = endTime = null;
                    errorText = null;
                  }), child: const Text('设为全天')),
                TextFormField(
                  initialValue: draftNote, onChanged: (value) => draftNote = value,
                  maxLength: 500, maxLines: 2,
                  decoration: const InputDecoration(labelText: '补充说明（选填）'),
                ),
                if (errorText != null)
                  Text(errorText!, style: const TextStyle(color: Palette.coral)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                key: const Key('daily_todo_save_button'),
                onPressed: () {
                  final draft = DailyTodo(
                    id: item?.id ?? '', date: dayString(start), endDate: dayString(end),
                    title: draftTitle.trim(), note: draftNote.trim(),
                    startTime: startTime, endTime: endTime,
                    completed: item?.completed ?? false,
                  );
                  final error = draft.title.isEmpty ? '请输入事项名称'
                    : end.isBefore(start) ? '结束日期不能早于开始日期'
                    : !draft.hasValidRange ? '请选择完整的起止时间，同日结束时间须晚于开始时间'
                    : null;
                  if (error != null) {
                    setDialogState(() => errorText = error);
                    return;
                  }
                  Navigator.pop(dialogContext, draft);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    if (!result.overlaps(from: dayString(_selected), to: dayString(_selected))) {
      _selectDate(DateTime.parse(result.date));
    }
    await _persist(result);
  }

  Widget _rangeField(String label, String value, IconData icon, Key key,
    VoidCallback onTap) => ListTile(
      key: key, contentPadding: EdgeInsets.zero, dense: true,
      title: Text(label), trailing: Icon(icon, size: 16),
      subtitle: Text(value), onTap: onTap,
    );

  Future<void> _remove(DailyTodo item) async {
    final sure = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除个人事项？'),
        content: Text('将删除“${item.title}”，此操作不能撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (sure == true && mounted) {
      await _delete(item);
    }
  }

  Widget _calendar(DateTime month, List<DailyTodo> items) =>
    LayoutBuilder(builder: (context, bounds) {
      final first = _gridStart(month);
      final rows = _weeks(month);
      final itemHeight = ((bounds.maxHeight - (rows - 1) * 2) / rows)
        .clamp(37.0, 85.0).toDouble();
      return GridView.builder(
        key: const Key('daily_todo_month_grid'),
        primary: false,
        physics: itemHeight * rows + (rows - 1) * 2 > bounds.maxHeight
          ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, mainAxisExtent: itemHeight,
          mainAxisSpacing: 2, crossAxisSpacing: 2,
        ),
        itemCount: rows * 7,
        itemBuilder: (context, index) {
          final date = DateTime(first.year, first.month, first.day + index);
          if (date.isBefore(_firstDate) || date.isAfter(_lastDate)) {
            return const SizedBox.shrink();
          }
          final day = dayString(date);
          final dayItems = _itemsFor(date, items);
          final selected = date == _selected;
          final today = DateUtils.isSameDay(date, chinaNow);
          final outside = date.month != month.month;
          final maxVisible = itemHeight >= 66 ? 2 : 1;
          final hidden = dayItems.length - maxVisible;
          return DragTarget<String>(
            key: Key('daily_todo_drop_$day'),
            onWillAcceptWithDetails: (details) =>
              !_saving && _draggedItem?.id == details.data,
            onAcceptWithDetails: (details) => _dropOnDate(details.data, date),
            builder: (context, hovering, rejected) => Material(
              color: hovering.isNotEmpty ? Palette.sage
                : selected ? const Color(0xFFF0F7FA) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                key: Key('daily_todo_day_$day'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => _selectDate(date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(children: [
                    SizedBox(height: 19, child: Center(child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? Palette.primary
                          : today ? Palette.sage : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('${date.day}', style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w800, color: selected ? Colors.white
                            : outside ? Palette.muted : Palette.deep)),
                      ),
                    ))),
                    for (final item in dayItems.take(maxVisible))
                      _draggable(item, date, 'calendar_$day', SizedBox(
                        width: double.infinity, height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: item.completed ? const Color(0xFFE5EAEE)
                              : const Color(0xFFC7D9EC),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(item.title, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: item.completed ? Palette.muted : Palette.deep,
                                decoration: item.completed ? TextDecoration.lineThrough : null)),
                          ),
                        ),
                      )),
                    if (hidden > 0 && itemHeight >= 19 + maxVisible * 16 + 12)
                      SizedBox(height: 12, child: Text('+$hidden',
                        style: const TextStyle(color: Palette.primary, fontSize: 9,
                          fontWeight: FontWeight.w900))),
                  ]),
                ),
              ),
            ),
          );
        },
      );
    });

  Widget _swipeableCalendar() => Row(children: [
    _monthDragTarget(-1, const SizedBox(width: 12, height: double.infinity),
      key: const Key('daily_todo_drag_previous_edge')),
    Expanded(child: GestureDetector(
      onHorizontalDragStart: (_) => _swipeDistance = 0,
      onHorizontalDragUpdate: (details) => _swipeDistance += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_swipeDistance.abs() >= 35 || velocity.abs() >= 250) {
          _moveMonth((_swipeDistance.abs() >= 35 ? _swipeDistance : velocity) < 0 ? 1 : -1);
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        // Keep the original drag recognizer attached while displaying new months.
        if (_dragMonth != null && _dragMonth != _month)
          Offstage(key: ValueKey(_dragMonth), offstage: true,
            child: _calendar(_dragMonth!, _dragItems)),
        Offstage(key: ValueKey(_month), offstage: false, child: _calendar(_month, _items)),
      ]),
    )),
    _monthDragTarget(1, const SizedBox(width: 12, height: double.infinity),
      key: const Key('daily_todo_drag_next_edge')),
  ]);

  Widget _dayList(DateTime day, List<DailyTodo> entries) {
    if (entries.isEmpty) {
      return const Align(alignment: Alignment.topLeft, child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        child: Text('当天暂无事项，点击“添加事项”记录个人待办',
          style: TextStyle(color: Palette.muted, fontSize: 11))));
    }
    return ListView.builder(
      key: const Key('daily_todo_day_list'),
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        final when = [
          item.date == item.endDate ? item.date : '${item.date} 至 ${item.endDate}',
          item.startTime == null ? '全天' : '${item.startTime}–${item.endTime}',
        ].join(' · ');
        final canEdit = !_saving && !_loading && _loadError == null;
        return SizedBox(height: 48, child: Row(children: [
          Checkbox(
            key: Key('daily_todo_check_${item.id}'),
            value: item.completed, visualDensity: VisualDensity.compact,
            onChanged: canEdit ? (value) =>
              _persist(item.copyWith(completed: value ?? false)) : null,
          ),
          Expanded(child: _draggable(item, day, 'day', InkWell(
            key: Key('daily_todo_edit_${item.id}'),
            onTap: canEdit ? () => _edit(item) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Palette.deep,
                    decoration: item.completed ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w700)),
                Text(when, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Palette.muted)),
              ],
            ),
          ))),
          IconButton(
            tooltip: '删除${item.title}', icon: const Icon(Icons.close, size: 16),
            color: Palette.muted, visualDensity: VisualDensity.compact,
            onPressed: canEdit ? () => _remove(item) : null,
          ),
        ]));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _itemsFor(_selected, _items);
    // The home screen contains multiple panels. The todo calendar must adapt
    // to the remaining height instead of reserving 94px for the day list on
    // every device (which overflowed at ~260px in widget tests / small phones).
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      final compact = height < 350;
      final headerHeight = compact ? 39.0 : 44.0;
      final monthHeight = compact ? 36.0 : 44.0;
      final weekdaysHeight = compact ? 16.0 : 20.0;
      final dayTitleHeight = compact ? 32.0 : 38.0;
      // Header + month navigation + weekday names + grid gap + separator +
      // day title. The grid and day list divide the rest of the height.
      const gapHeight = 5.0;
      const separatorHeight = 1.0;
      final flexible = (height - 2 - headerHeight - monthHeight -
          weekdaysHeight - gapHeight - separatorHeight - dayTitleHeight)
          .clamp(0.0, double.infinity).toDouble();
      final dayListHeight = (flexible * (compact ? 0.35 : 0.20))
          .clamp(0.0, compact ? 56.0 : 94.0).toDouble();

      return Container(
        key: const Key('daily_todo_panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Palette.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          SizedBox(
            height: headerHeight,
            child: ColoredBox(
              color: Palette.deep,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Expanded(child: Text(_draggedItem == null ? '每日事项' : '拖至月历两侧可连续翻月',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800))),
                  IconButton(
                    key: const Key('daily_todo_add_header'),
                    tooltip: '新增每日事项',
                    onPressed: _loading || _loadError != null || _saving
                      ? null : () => _edit(),
                    icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 21),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34, height: 34),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ]),
              ),
            ),
          ),
            SizedBox(
              height: monthHeight,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _monthDragTarget(-1, IconButton(
                    onPressed: () => _moveMonth(-1), tooltip: '上个月',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34, height: 34),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.chevron_left),
                  ), key: const Key('daily_todo_drag_previous_month')),
                  TextButton(
                    key: const Key('daily_todo_choose_date'),
                    onPressed: _chooseDate,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_month.year}年${_month.month}月',
                        style: const TextStyle(fontSize: 14,
                          color: Palette.deep, fontWeight: FontWeight.w800)),
                      const Icon(Icons.arrow_drop_down,
                        color: Palette.primary),
                    ]),
                  ),
                  _monthDragTarget(1, IconButton(
                    onPressed: () => _moveMonth(1), tooltip: '下个月',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34, height: 34),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.chevron_right),
                  ), key: const Key('daily_todo_drag_next_month')),
                ],
              ),
            ),
            SizedBox(
              height: weekdaysHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  for (final day in ['周一', '周二', '周三', '周四', '周五', '周六', '周日'])
                    Expanded(child: Center(child: Text(day,
                      style: const TextStyle(color: Palette.muted,
                        fontWeight: FontWeight.w600, fontSize: 11)))),
                ]),
              ),
            ),
            const SizedBox(height: gapHeight),
            Expanded(child: _swipeableCalendar()),
            const Divider(height: separatorHeight),
            SizedBox(
              height: dayTitleHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(children: [
                  Expanded(child: Text(
                    _loading ? '读取事项中…'
                      : '${_selected.month}月${_selected.day}日 · ${entries.length} 项',
                    style: const TextStyle(color: Palette.deep,
                      fontSize: 12, fontWeight: FontWeight.w800))),
                  TextButton(
                    key: const Key('daily_todo_add_day'),
                    onPressed: _saving || _loading || _loadError != null ? null : () => _edit(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3)),
                    child: const Text('＋ 添加事项',
                      style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ),
            SizedBox(
              height: dayListHeight,
              child: Stack(fit: StackFit.expand, children: [
                if (_dragDay != null && _dragDay != _selected)
                  Offstage(key: ValueKey(_dragDay), offstage: true,
                    child: _dayList(_dragDay!, _itemsFor(_dragDay!, _dragItems))),
                Offstage(
                  key: ValueKey(_selected), offstage: false,
                  child: _loadError == null
                    ? _dayList(_selected, entries)
                    : TextButton(onPressed: _reload, child: const Text('事项读取失败，重试')),
                ),
              ]),
            ),
        ]),
      );
    });
  }
}
