import 'dart:async';
import 'package:flutter/material.dart';
import '../core/daily_todos.dart';
import '../core/holiday_calendar.dart';
import '../data/holiday_calendar_service.dart';
import '../data/repository.dart';
import '../widgets/holiday_calendar_widgets.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// The user's private month-view todo calendar. No company-task or log APIs.
class DailyTodosCalendar extends StatefulWidget {
  final int userId;
  final PandoraRepository? repo;
  final HolidayCalendarService? holidayService;
  const DailyTodosCalendar({super.key, required this.userId,
    this.repo, this.holidayService});
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
  HolidayCalendarView? _holidayView;
  int _holidayRequestId = 0;
  Timer? _monthDragHoverTimer;
  int? _hoveringMonthArrow;
  // Keep the original draggable mounted even after the visible month changes.
  // Otherwise Flutter cancels a drag started from a calendar day when that
  // day's widget disappears on the next page.
  String? _draggingTodoId;
  DateTime? _dragOriginMonth;
  final GlobalKey _monthGridViewportKey = GlobalKey();
  double _monthSwipeDistance = 0;

  @override
  void dispose() {
    _monthDragHoverTimer?.cancel();
    super.dispose();
  }

  void _fetchHolidays({bool forceRefresh = false}) {
    final service = widget.holidayService;
    if (service == null) return;
    final requestId = ++_holidayRequestId;
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    _applyHolidayRequest(service.loadRange(first, last,
      forceRefresh: forceRefresh), requestId);
  }

  Future<void> _applyHolidayRequest(
      Future<HolidayCalendarView> future, int requestId) async {
    try {
      final result = await future;
      if (!mounted || requestId != _holidayRequestId) return;
      setState(() => _holidayView = result);
    } catch (_) {
      // Holiday failure cannot block or replace private todo information.
      if (mounted && requestId == _holidayRequestId) {
        setState(() => _holidayView = const HolidayCalendarView({}));
      }
    }
  }

  DailyTodoStorage get _storage => DailyTodoStorage(widget.userId);

  @override
  void initState() {
    super.initState();
    final today = chinaNow;
    _selected = DateTime(today.year, today.month, today.day);
    _month = DateTime(today.year, today.month);
    _reload();
    _fetchHolidays();
  }

  @override
  void didUpdateWidget(covariant DailyTodosCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.repo != widget.repo) {
      _reload();
    }
    if (oldWidget.holidayService != widget.holidayService) _fetchHolidays();
  }

  DailyTodo _withLocalPresentation(DailyTodo cloud, DailyTodo local) => DailyTodo(
    id: cloud.id,
    date: cloud.date,
    endDate: local.endDate,
    title: cloud.title,
    note: cloud.note,
    completed: cloud.completed,
    colorValue: cloud.colorValue,
    startTime: cloud.startTime,
    endTime: cloud.endTime,
    sortOrder: cloud.sortOrder,
  );

  bool _cloudChanged(DailyTodo before, DailyTodo after) =>
      before.date != after.date ||
      before.title != after.title ||
      before.note != after.note ||
      before.completed != after.completed ||
      before.colorValue != after.colorValue ||
      before.startTime != after.startTime ||
      before.endTime != after.endTime ||
      before.sortOrder != after.sortOrder;

  Future<void> _loadItems() async {
    final local = await _storage.read();
    final repo = widget.repo;
    if (repo == null) {
      _items = local;
      return;
    }

    final firstDay = DateTime(_month.year, _month.month, 1);
    final from = dayString(firstDay);
    final to = dayString(DateTime(
      _month.year,
      _month.month,
      DateUtils.getDaysInMonth(_month.year, _month.month),
    ));

    final cloud = await repo.dailyItems(from: from, to: to);
    final localById = <String, DailyTodo>{
      for (final item in local)
        if (item.id.isNotEmpty) item.id: item,
    };
    final localOrder = <String, int>{
      for (var i = 0; i < local.length; i++)
        if (local[i].id.isNotEmpty) local[i].id: i,
    };

    final visible = cloud.map((item) {
      final localItem = localById[item.id];
      return localItem == null ? item : _withLocalPresentation(item, localItem);
    }).toList()
      ..sort((a, b) {
        final ai = localOrder[a.id];
        final bi = localOrder[b.id];
        if (ai == null && bi == null) return 0;
        if (ai == null) return 1;
        if (bi == null) return -1;
        return ai.compareTo(bi);
      });

    _items = [
      ...local.where((item) =>
          item.date.compareTo(from) < 0 || item.date.compareTo(to) > 0),
      ...visible,
    ];
    await _storage.write(_items);
  }

  Future<void> _reload() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      await _loadItems();
      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = '$e'; _loading = false; });
    }
  }

  void _moveMonth(int delta) {
    final newMonth = DateTime(_month.year, _month.month + delta);
    setState(() {
      _month = newMonth;
      final days = DateUtils.getDaysInMonth(newMonth.year, newMonth.month);
      _selected = DateTime(newMonth.year, newMonth.month, _selected.day.clamp(1, days).toInt());
      _holidayView = null;
    });
    if (widget.repo != null) _reload();
    _fetchHolidays();
  }

  /// Dragging may keep the selected day in the previous month so the
  /// originating draggable stays mounted while the grid navigates.
  void _changeMonthWhileDragging(int delta) {
    if (!mounted) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _holidayView = null;
    });
    if (widget.repo != null) _reload();
    _fetchHolidays();
  }

  void _cancelMonthHover() {
    _monthDragHoverTimer?.cancel();
    _monthDragHoverTimer = null;
    _hoveringMonthArrow = null;
  }

  void _scheduleMonthHover(int delta) {
    if (_saving) return;
    if (_hoveringMonthArrow != delta) {
      _cancelMonthHover();
      _hoveringMonthArrow = delta;
    }
    if (_monthDragHoverTimer?.isActive == true) return;
    _monthDragHoverTimer = Timer(const Duration(milliseconds: 650), () {
      _monthDragHoverTimer = null;
      if (!mounted || _saving || _hoveringMonthArrow != delta) return;
      _changeMonthWhileDragging(delta);
      // The finger can remain stationary at the edge. Every timer tick must
      // keep paging without requiring another pointer-move event.
      _scheduleMonthHover(delta);
    });
  }

  void _startTodoDrag(String itemId) {
    _cancelMonthHover();
    setState(() {
      _draggingTodoId = itemId;
      _dragOriginMonth = DateTime(_month.year, _month.month);
    });
  }

  void _updateTodoDrag(DragUpdateDetails details) {
    if (_draggingTodoId == null) return;
    final context = _monthGridViewportKey.currentContext;
    final render = context?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final position = render.globalToLocal(details.globalPosition);
    final width = render.size.width;
    final height = render.size.height;
    // A generous vertical zone includes the month header and its arrows.
    // Horizontal edge paging also works for tasks dragged from the day list.
    if (position.dy < -85 || position.dy > height + 15 ||
        position.dx < -45 || position.dx > width + 45) {
      _cancelMonthHover();
      return;
    }
    final edgeWidth = (width * 0.13).clamp(32.0, 56.0).toDouble();
    if (position.dx >= width - edgeWidth) {
      _scheduleMonthHover(1); // Right edge: as many future months as needed.
    } else if (position.dx <= edgeWidth) {
      _scheduleMonthHover(-1);
    } else {
      _cancelMonthHover(); // Stop immediately when moving back into the grid.
    }
  }

  void _endTodoDrag() {
    _cancelMonthHover();
    if (!mounted) return;
    setState(() {
      _draggingTodoId = null;
      _dragOriginMonth = null;
    });
  }

  void _endMonthSwipe(DragEndDetails details) {
    if (_draggingTodoId != null) return;
    final velocity = details.primaryVelocity ?? 0;
    final delta = _monthSwipeDistance;
    _monthSwipeDistance = 0;
    // Ordinary horizontal swipes flip the month as on a phone home screen.
    if (delta < -45 || (delta < -10 && velocity < -220)) {
      _moveMonth(1);
    } else if (delta > 45 || (delta > 10 && velocity > 220)) {
      _moveMonth(-1);
    }
  }

  /// Long-press a task, hover any calendar edge or month arrow to page.
  Widget _monthDragArrow(int delta) => DragTarget<String>(
    key: Key(delta < 0 ? 'daily_todo_drag_prev_month'
      : 'daily_todo_drag_next_month'),
    onWillAcceptWithDetails: (details) => !_saving &&
      _items.any((item) => item.id == details.data),
    onMove: (_) => _scheduleMonthHover(delta),
    onLeave: (_) {
      // Switching the month rebuilds the arrows; their old DragTarget emits
      // onLeave even though the user's finger remains at the same edge.
      if (_draggingTodoId == null) _cancelMonthHover();
    },
    onAcceptWithDetails: (_) {
      if (_draggingTodoId == null) _cancelMonthHover();
    },
    builder: (context, candidates, rejected) => Container(
      decoration: BoxDecoration(
        color: candidates.isNotEmpty ? Palette.rose : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        onPressed: () => _moveMonth(delta),
        tooltip: delta < 0 ? '上个月 · 长按事项靠左边缘连续翻月' : '下个月 · 长按事项靠右边缘连续翻月',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        icon: Icon(delta < 0 ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded),
      ),
    ),
  );

  void _selectCalendarDate(DateTime date) {
    final differentMonth = date.month != _month.month || date.year != _month.year;
    setState(() {
      _selected = DateUtils.dateOnly(date);
      if (differentMonth) {
        _month = DateTime(date.year, date.month);
        _holidayView = null;
      }
    });
    if (differentMonth) {
      if (widget.repo != null) _reload();
      _fetchHolidays();
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context, initialDate: _selected,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      helpText: '选择每日事项日期',
    );
    if (date != null && mounted) {
      setState(() {
        _selected = DateTime(date.year, date.month, date.day);
        _month = DateTime(date.year, date.month);
        _holidayView = null;
      });
      if (widget.repo != null) _reload();
      _fetchHolidays();
    }
  }

  List<DailyTodo> get _selectedItems => _items
      .where((item) => item.overlaps(from: dayString(_selected),
        to: dayString(_selected))).toList();

  Future<bool> _save(List<DailyTodo> updated) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final normalized = _withSortOrder(updated);
      final repo = widget.repo;
      var savedItems = [...normalized];

      if (repo != null) {
        final oldById = <String, DailyTodo>{
          for (final item in _items)
            if (item.id.isNotEmpty) item.id: item,
        };
        final updatedIds = normalized
            .where((item) => item.id.isNotEmpty)
            .map((item) => item.id)
            .toSet();

        // Delete cloud rows removed by the v2 UI.
        for (final old in _items) {
          if (old.id.isNotEmpty && !updatedIds.contains(old.id)) {
            await repo.deleteDailyItem(old.id);
          }
        }
        final cloudSaved = <DailyTodo>[];
        for (final item in normalized) {
          final before = item.id.isEmpty ? null : oldById[item.id];

          if (before == null) {
            final cloud = await repo.createDailyItem(
              date: item.date,
              endDate: item.endDate,
              title: item.title,
              note: item.note,
              completed: item.completed,
              colorValue: item.colorValue,
              startTime: item.startTime,
              endTime: item.endTime,
              sortOrder: item.sortOrder,
            );
            cloudSaved.add(_withLocalPresentation(cloud, item));
          } else if (_cloudChanged(before, item)) {
            final cloud = await repo.updateDailyItem(item);
            cloudSaved.add(_withLocalPresentation(cloud, item));
          } else {
            // endDate remains local until the backend schema supports ranges.
            cloudSaved.add(item);
          }
        }
        savedItems = cloudSaved;
      }

      await _storage.write(savedItems);
      if (!mounted) return false;
      setState(() => _items = savedItems);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存每日事项失败：$error')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<DailyTodo> _withSortOrder(List<DailyTodo> items) {
    final perDay = <String, int>{};
    return [for (final item in items)
      item.copyWith(sortOrder: perDay.update(item.date, (value) => value + 1,
        ifAbsent: () => 0))];
  }

  Future<void> _edit([DailyTodo? item]) async {
    var draftTitle = item?.title ?? '';
    var draftNote = item?.note ?? '';
    var draftColor = item?.colorValue ?? DailyTodoColors.defaultColor;
    var draftDate = item?.date ?? dayString(_selected);
    var draftEndDate = item?.endDate ?? draftDate;
    TimeOfDay? start = _parseTime(item?.startTime);
    TimeOfDay? end = _parseTime(item?.endTime);
    String? errorText;
    String? timeError;
    final result = await showDialog<DailyTodo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.tryParse(draftDate) ?? _selected,
              firstDate: DateTime(2000), lastDate: DateTime(2100),
              helpText: '选择事项的目标日期',
            );
            if (picked != null && dialogContext.mounted) {
              setDialogState(() {
                final nextDate = dayString(picked);
                // Shift an existing multi-day item as a whole when moving its start.
                final oldStart = DateTime.tryParse(draftDate);
                final oldEnd = DateTime.tryParse(draftEndDate);
                if (oldStart != null && oldEnd != null) {
                  final oldStartUtc = DateTime.utc(oldStart.year, oldStart.month, oldStart.day);
                  final nextStartUtc = DateTime.utc(picked.year, picked.month, picked.day);
                  final oldEndUtc = DateTime.utc(oldEnd.year, oldEnd.month, oldEnd.day);
                  final delta = nextStartUtc.difference(oldStartUtc).inDays;
                  draftEndDate = dayString(oldEndUtc.add(Duration(days: delta)));
                }
                draftDate = nextDate;
                timeError = null;
              });
            }
          }

          Future<void> pickEndDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.tryParse(draftEndDate) ?? _selected,
              firstDate: DateTime.tryParse(draftDate) ?? DateTime(2000),
              lastDate: DateTime(2100),
              helpText: '选择事项结束日期',
            );
            if (picked != null && dialogContext.mounted) {
              setDialogState(() { draftEndDate = dayString(picked); timeError = null; });
            }
          }

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: isStart
                  ? start ?? const TimeOfDay(hour: 9, minute: 0)
                  : end ?? const TimeOfDay(hour: 10, minute: 0),
              helpText: isStart ? '选择开始时间' : '选择结束时间',
              initialEntryMode: TimePickerEntryMode.input,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (picked != null && dialogContext.mounted) {
              setDialogState(() {
                if (isStart) { start = picked; } else { end = picked; }
                timeError = null;
              });
            }
          }

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97B9E)),
              const SizedBox(width: 8),
              Expanded(child: Text(item == null ? '新增每日事项' : '编辑每日事项')),
            ]),
            content: SizedBox(
              width: 370,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    key: const Key('daily_todo_edit_date'),
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text('日期：$draftDate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42)),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const Key('daily_todo_end_date'),
                    onPressed: pickEndDate,
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text('结束日期：$draftEndDate'),
                  ),
                  const SizedBox(height: 6),
                  const Text('长按事项拖至日历右边缘，可连续翻到任意未来月份再放下',
                    style: TextStyle(color: Palette.muted, fontSize: 11)),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('daily_todo_title_input'),
                    initialValue: draftTitle,
                    onChanged: (value) => draftTitle = value,
                    maxLength: 100, autofocus: true,
                    decoration: InputDecoration(
                      labelText: '事项名称', errorText: errorText,
                      prefixIcon: const Icon(Icons.favorite_border_rounded),
                    ),
                  ),
                  TextFormField(
                    initialValue: draftNote,
                    onChanged: (value) => draftNote = value,
                    maxLength: 500, maxLines: 2,
                    decoration: const InputDecoration(labelText: '补充说明（选填）'),
                  ),
                  const SizedBox(height: 12),
                  const Text('事项颜色', style: TextStyle(
                      fontWeight: FontWeight.w800, color: Palette.deep)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    for (final color in DailyTodoColors.choices)
                      Semantics(
                        label: '事项颜色 ${DailyTodoColors.choices.indexOf(color) + 1}',
                        child: InkWell(
                          key: Key('daily_todo_color_$color'),
                          onTap: () => setDialogState(() => draftColor = color),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Color(color), shape: BoxShape.circle,
                              border: Border.all(
                                color: draftColor == color
                                    ? Palette.deep : Colors.white,
                                width: draftColor == color ? 2.5 : 1.5,
                              ),
                            ),
                            child: draftColor == color
                                ? const Icon(Icons.check_rounded,
                                    color: Palette.deep, size: 21)
                                : null,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  const Text('时间安排（选填）', style: TextStyle(
                      fontWeight: FontWeight.w800, color: Palette.deep)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      key: const Key('daily_todo_start_time'),
                      onPressed: () => pickTime(true),
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: Text(start == null ? '开始时间' : _formatTime(start!)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 43),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text('—', style: TextStyle(color: Palette.muted)),
                    ),
                    Expanded(child: OutlinedButton.icon(
                      key: const Key('daily_todo_end_time'),
                      onPressed: () => pickTime(false),
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: Text(end == null ? '结束时间' : _formatTime(end!)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 43),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                    )),
                  ]),
                  if (start != null || end != null)
                    Align(alignment: Alignment.centerRight, child: TextButton(
                      key: const Key('daily_todo_clear_time'),
                      onPressed: () => setDialogState(() {
                        start = null; end = null; timeError = null;
                      }),
                      child: const Text('清除时间 · 全天事项'),
                    )),
                  if (timeError != null)
                    Text(timeError!, style: const TextStyle(
                      fontSize: 12, color: Colors.red)),
                ],
              )),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
              FilledButton(
                key: const Key('daily_todo_save_button'),
                onPressed: () {
                  if (draftTitle.trim().isEmpty) {
                    setDialogState(() => errorText = '请输入事项名称');
                    return;
                  }
                  final startText = start == null ? null : _formatTime(start!);
                  final endText = end == null ? null : _formatTime(end!);
                  if (!DailyTodo.validTimeRange(startText, endText,
                      acrossDays: draftDate != draftEndDate) ||
                      draftEndDate.compareTo(draftDate) < 0) {
                    setDialogState(() => timeError = '请确认起止日期及时间范围有效');
                    return;
                  }
                  final id = item?.id ??
                      (widget.repo == null
                        ? DateTime.now().microsecondsSinceEpoch.toString()
                        : '');
                  Navigator.pop(dialogContext, DailyTodo(
                    id: id, date: draftDate, endDate: draftEndDate,
                    title: draftTitle.trim(), note: draftNote.trim(),
                    completed: item?.completed ?? false,
                    colorValue: draftColor, startTime: startText, endTime: endText,
                  ));
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final updated = [..._items];
    final index = updated.indexWhere((e) => e.id == result.id);
    if (index >= 0) { updated[index] = result; } else { updated.add(result); }
    final saved = await _save(updated);
    if (saved && mounted && result.date != dayString(_selected)) {
      final target = DateTime.tryParse(result.date);
      if (target != null) _selectCalendarDate(target);
    }
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 ||
        minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _moveToDate(String itemId, String targetDate) async {
    if (_saving) return;
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0 || _items[index].date == targetDate) return;
    final updated = moveDailyTodoToDate(_items, itemId, targetDate);
    final saved = await _save(updated);
    if (saved && mounted) {
      final parsed = DateTime.tryParse(targetDate);
      if (parsed != null) _selectCalendarDate(parsed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移动到 $targetDate')),
      );
    }
  }

  Future<void> _reorderDay(int oldIndex, int newIndex) async {
    if (_saving) return;
    final updated = reorderDailyTodosForDay(
        _items, dayString(_selected), oldIndex, newIndex);
    await _save(updated);
  }

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
      await _save(_items.where((e) => e.id != item.id).toList());
    }
  }

  Widget _dragFeedback(DailyTodo item) => Material(
    elevation: 7,
    borderRadius: BorderRadius.circular(12),
    color: Color(item.colorValue),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 175),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.touch_app_rounded, size: 15, color: Palette.deep),
        const SizedBox(width: 5),
        Flexible(child: Text(item.title, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 12, color: Palette.deep))),
      ]),
    ),
  );

  // 与「工作 → 视图 → 日历」保持相同的月视图布局：
  // 每周是一整行、周之间用横线分隔，日期不绘制独立的圆角方框。
  // 仅复用日历呈现方式；个人每日事项与工作任务的数据仍完全隔离。
  // Keep the original month grid in the widget tree while a drag is active.
  // Replacing the source grid would dispose the LongPressDraggable and abort
  // the drag after the first month. Offstage retains the source and its gesture
  // recognizer; the visible overlay receives the destination drop.
  Widget _calendar() => LayoutBuilder(builder: (context, bounds) {
    final origin = _dragOriginMonth ?? _month;
    final showingAnotherMonth = _dragOriginMonth != null &&
        (origin.year != _month.year || origin.month != _month.month);
    return Stack(
      key: _monthGridViewportKey,
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: showingAnotherMonth,
          child: _calendarMonth(origin, bounds.maxHeight),
        ),
        if (showingAnotherMonth)
          _calendarMonth(_month, bounds.maxHeight),
      ],
    );
  });

  Widget _calendarMonth(DateTime visibleMonth, double availableHeight) {
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final weekStart = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    final rowCount = ((first.weekday - 1 + last.day + 7) ~/ 7)
        .clamp(5, 6).toInt();
    final weekHeight = availableHeight / rowCount;

    return Column(
      key: const Key('daily_todo_month_grid'),
      children: [
        for (var week = 0; week < rowCount; week++)
          Expanded(
            child: Container(
              key: Key('daily_todo_week_$week'),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Palette.divider)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: _calendarDateCell(
                        weekStart.add(Duration(days: week * 7 + weekday)),
                        (weekHeight - 4).clamp(0.0, double.infinity).toDouble(),
                        visibleMonth,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _calendarDateCell(DateTime date, double height,
      DateTime visibleMonth) {
    final day = dayString(date);
    final outsideMonth = date.month != visibleMonth.month ||
        date.year != visibleMonth.year;
    final dayItems = _items.where((item) =>
      item.overlaps(from: day, to: day)).toList();
    final holiday = _holidayView?.on(date);
    final selected = DateUtils.isSameDay(date, _selected);
    final today = DateUtils.isSameDay(date, chinaNow);
    // 日期和事项共享周行高度，但绝不为了显示 +N 而隐藏最后一个
    // 可长按的事项标签。较窄手机仍然优先保留拖动入口。
    // 小屏首页中整个月历可能被压到每周不足 20px。先扣除内边距，
    // 再计算日期高度，确保 Column 的子元素永远不会超过可用高度。
    final cellVerticalPadding = height < 24 ? 0.0 : 3.0;
    final innerHeight = (height - cellVerticalPadding * 2)
        .clamp(0.0, double.infinity).toDouble();
    final preferredDateHeight = height < 28 ? height.clamp(0.0, 20.0).toDouble()
        : height < 45 ? 21.0 : height < 85 ? 23.0 : 26.0;
    final dateHeight = preferredDateHeight.clamp(0.0, innerHeight).toDouble();
    final showLabels = height >= 43;
    const chipHeight = 15.0;
    const chipGap = 2.0;
    const chipStride = chipHeight + chipGap;
    const moreHeight = 12.0;
    const labelTopGap = 3.0;
    // 节日名称在空间够用时仍然显示，空间紧张时优先显示事项。
    final plannedChips = (dayItems.length < 2 ? dayItems.length : 2);
    final plannedHeight = plannedChips * chipStride +
        (dayItems.length > 2 ? moreHeight : 0);
    final showFestival = !outsideMonth &&
        holiday?.festivalLabel.isNotEmpty == true && height >= 85 &&
        (!showLabels || dayItems.isEmpty ||
          innerHeight - 1 - dateHeight - labelTopGap - 13 >= plannedHeight);
    // 留出额外 1px 安全余量，避免不同平台字体的小数像素溢出。
    final labelSpace = innerHeight - 1 - dateHeight -
        (showLabels ? labelTopGap : 0) - (showFestival ? 13 : 0);
    var visible = showLabels ? (dayItems.length < 2 ? dayItems.length : 2) : 0;
    while (visible > 0 && visible * chipStride > labelSpace) {
      visible--;
    }
    final hidden = dayItems.length - visible;
    final showMore = showLabels && hidden > 0 &&
        visible * chipStride + moreHeight <= labelSpace;

    return DragTarget<String>(
      key: Key('daily_todo_drop_$day'),
      onWillAcceptWithDetails: (details) => !_saving && _items.any(
        (item) => item.id == details.data && item.date != day,
      ),
      onAcceptWithDetails: (details) => _moveToDate(details.data, day),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return InkWell(
          key: Key('daily_todo_day_$day'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => _selectCalendarDate(date),
          child: Container(
            key: Key('daily_todo_cell_$day'),
            height: height,
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: cellVerticalPadding),
            decoration: BoxDecoration(
              color: hovering ? Palette.rose
                  : selected ? const Color(0xFFF0F7FA)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            // Very short calendar rows (e.g. a 310px home panel) cannot
            // accommodate a Column with a text line and a holiday badge.
            // Render a single, tightly constrained layer instead. Keep the
            // drag target and day-tap behavior unchanged.
            child: !showLabels
              ? Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Center(child: SizedBox(
                      width: dateHeight,
                      height: dateHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected ? Palette.primary
                              : today ? Palette.sage : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('${date.day}', style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white
                                : outsideMonth ? Palette.muted : Palette.deep,
                          )),
                        ),
                      ),
                    )),
                    if (!outsideMonth && dateHeight >= 14 &&
                        holiday?.dayTypeLabel.isNotEmpty == true)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: HolidayDayBadge(day: holiday),
                      ),
                  ],
                )
              : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: dateHeight,
                  child: Stack(children: [
                    Center(child: Container(
                      width: dateHeight,
                      height: dateHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Palette.primary
                            : today ? Palette.sage : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text('${date.day}', style: TextStyle(
                        fontSize: dateHeight < 16
                            ? (dateHeight * 0.72).clamp(3.0, 12.0).toDouble()
                            : 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white
                            : outsideMonth ? Palette.muted : Palette.deep,
                      )),
                    )),
                    if (!outsideMonth &&
                        holiday?.dayTypeLabel.isNotEmpty == true)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: HolidayDayBadge(day: holiday),
                      ),
                  ]),
                ),
                if (showFestival)
                  SizedBox(
                    height: 13,
                    child: HolidayFestivalLabel(day: holiday),
                  ),
                if (showLabels) const SizedBox(height: labelTopGap),
                for (final item in dayItems.take(visible))
                  Padding(
                    padding: const EdgeInsets.only(bottom: chipGap),
                    child: LongPressDraggable<String>(
                      key: Key('daily_todo_drag_calendar_${item.id}'),
                      data: item.id,
                      maxSimultaneousDrags: _saving ? 0 : 1,
                      onDragStarted: () => _startTodoDrag(item.id),
                      onDragUpdate: _updateTodoDrag,
                      onDragEnd: (_) => _endTodoDrag(),
                      feedback: _dragFeedback(item),
                      childWhenDragging: const SizedBox(height: chipHeight),
                      child: Container(
                        height: chipHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: item.completed
                              ? const Color(0xFFE7E7EC)
                              : Color(item.colorValue),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: item.completed ? Palette.muted : Palette.deep,
                            decoration: item.completed
                                ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showMore)
                  SizedBox(
                    key: Key('daily_todo_more_$day'),
                    height: moreHeight,
                    child: Center(
                      child: Text('+$hidden',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Palette.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _selectedItems;
    // The home screen contains multiple panels. The todo calendar must adapt
    // to the remaining height instead of reserving 94px for the day list on
    // every device (which overflowed at ~260px in widget tests / small phones).
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      final compact = height < 350;
      final headerHeight = compact ? 39.0 : 44.0;
      final monthHeight = compact ? 36.0 : 44.0;
      final weekdaysHeight = compact ? 16.0 : 20.0;
      // Two lines (selected date + holiday details) can exceed 32 logical
      // pixels even with default text scaling on Android. Reserve safe space.
      final dayTitleHeight = compact ? 38.0 : 42.0;
      // Header + month navigation + weekday names + grid gap + separator +
      // day title. The grid and day list divide the rest of the height.
      const gapHeight = 5.0;
      const separatorHeight = 1.0;
      final flexible = (height - 2 - headerHeight - monthHeight -
          weekdaysHeight - gapHeight - separatorHeight - dayTitleHeight)
          .clamp(0.0, double.infinity).toDouble();
      // 列表显示两条完整卡片，其余内容在列表内滚动；节省下来的
      // 高度交给月历，确保最多两条事项标签及 +N 能直接拖放/查看。
      final dayListHeight = (flexible * (compact ? 0.35 : 0.27))
          .clamp(0.0, compact ? 56.0 : 140.0).toDouble();

      return Container(
        key: const Key('daily_todo_panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFD),
          border: Border.all(color: const Color(0xFFF1D8E4)),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(children: [
          SizedBox(
            height: headerHeight,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFDAEA), Color(0xFFE6E6FF)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFC66A97), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('每日事项', style: TextStyle(
                    color: Palette.deep, fontSize: 15,
                    fontWeight: FontWeight.w800))),
                  IconButton(
                    key: const Key('daily_todo_add_header'),
                    tooltip: '新增每日事项',
                    onPressed: _loading || _loadError != null || _saving
                      ? null : () => _edit(),
                    icon: const Icon(Icons.add_circle_rounded,
                      color: Color(0xFFC56B98), size: 23),
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
          if (_loading)
            const Expanded(child: Center(child:
              CircularProgressIndicator(strokeWidth: 2)))
          else if (_loadError != null)
            Expanded(child: Center(child: TextButton(
              onPressed: _reload,
              child: const Text('每日事项读取失败，点击重试'))))
          else ...[
            SizedBox(
              height: monthHeight,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _monthDragArrow(-1),
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
                  _monthDragArrow(1),
                ],
              ),
            ),
            SizedBox(
              height: weekdaysHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(children: [
                  for (final day in ['周一', '周二', '周三', '周四', '周五', '周六', '周日'])
                    Expanded(child: Center(child: Text(day,
                      style: TextStyle(
                        color: Palette.deep,
                        fontWeight: FontWeight.w700, fontSize: 10)))),
                ]),
              ),
            ),
            const SizedBox(height: gapHeight),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                key: const Key('daily_todo_month_swipe'),
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _monthSwipeDistance = 0,
                onHorizontalDragUpdate: (details) {
                  if (_draggingTodoId == null) {
                    _monthSwipeDistance += details.primaryDelta ?? 0;
                  }
                },
                onHorizontalDragEnd: _endMonthSwipe,
                onHorizontalDragCancel: () => _monthSwipeDistance = 0,
                child: _calendar(),
              ),
            )),
            const Divider(height: separatorHeight,
              color: Color(0xFFF0DFE8)),
            SizedBox(
              height: dayTitleHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(children: [
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${_selected.month}月${_selected.day}日 · ${entries.length} 项',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Palette.deep,
                            fontSize: 12, fontWeight: FontWeight.w800)))),
                      if (_holidayView?.on(_selected) != null)
                        Flexible(child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectedHolidayInfo(day: _holidayView!.on(_selected))))
                      else if (_holidayView?.notice.isNotEmpty == true)
                        Flexible(child: InkWell(
                          key: const Key('holiday_home_retry'),
                          onTap: () => _fetchHolidays(forceRefresh: true),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('${_holidayView!.notice} · 点击重试',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9,
                                color: Palette.muted))),
                        )),
                      if (_holidayView?.on(_selected) == null &&
                          _holidayView?.notice.isNotEmpty != true && entries.isNotEmpty)
                        const Flexible(child: Text('长按拖到左右边缘可连续翻月 · 松开放到目标日',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, color: Palette.muted))),
                    ],
                  )),
                  TextButton(
                    key: const Key('daily_todo_add_day'),
                    onPressed: _saving ? null : () => _edit(),
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
              child: entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(children: [
                      Icon(Icons.favorite_border_rounded,
                        color: Color(0xFFDE9BB6), size: 19),
                      SizedBox(width: 8),
                      Expanded(child: Text('今天还没有小计划，点「添加事项」开始吧 ✨',
                        maxLines: 2,
                        style: TextStyle(color: Palette.muted, fontSize: 11))),
                    ]),
                  )
                : ReorderableListView.builder(
                    key: const Key('daily_todo_day_list'),
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: entries.length,
                    onReorder: _reorderDay,
                    itemBuilder: (ctx, i) {
                      final item = entries[i];
                      return Padding(
                        key: ValueKey('daily_todo_row_${item.id}'),
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Container(
                          height: 57,
                          decoration: BoxDecoration(
                            color: Color(item.colorValue).withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(item.colorValue)),
                          ),
                          child: Row(children: [
                            Checkbox(
                              key: Key('daily_todo_check_${item.id}'),
                              value: item.completed,
                              activeColor: const Color(0xFFD4779D),
                              onChanged: _saving ? null : (value) =>
                                _save(_items.map((e) => e.id == item.id
                                  ? e.copyWith(completed: value ?? false)
                                  : e).toList()),
                              visualDensity: VisualDensity.compact,
                            ),
                            Expanded(child: LongPressDraggable<String>(
                              key: Key('daily_todo_drag_day_${item.id}'),
                              data: item.id,
                              maxSimultaneousDrags: _saving ? 0 : 1,
                              onDragStarted: () => _startTodoDrag(item.id),
                              onDragUpdate: _updateTodoDrag,
                              onDragEnd: (_) => _endTodoDrag(),
                              feedback: _dragFeedback(item),
                              childWhenDragging: const Opacity(
                                opacity: 0.35, child: Text('拖动中…')),
                              child: InkWell(
                                key: Key('daily_todo_edit_${item.id}'),
                                onTap: _saving ? null : () => _edit(item),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.title, maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12,
                                        color: Palette.deep,
                                        decoration: item.completed
                                          ? TextDecoration.lineThrough : null,
                                        fontWeight: FontWeight.w800)),
                                    Text([
                                      if (item.date != item.endDate)
                                        '${item.date} 至 ${item.endDate}',
                                      item.timeLabel,
                                      if (item.note.isNotEmpty) item.note,
                                    ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10, color: Palette.muted)),
                                  ],
                                ),
                              ),
                            )),
                            IconButton(
                              tooltip: '删除${item.title}',
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Palette.muted,
                              constraints: const BoxConstraints.tightFor(
                                width: 30, height: 38),
                              padding: EdgeInsets.zero,
                              onPressed: _saving ? null : () => _remove(item),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              enabled: !_saving,
                              child: const Tooltip(
                                message: '拖动排序',
                                child: SizedBox(width: 29, height: 50,
                                  child: Icon(Icons.drag_indicator_rounded,
                                    color: Palette.muted, size: 19)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ]),
      );
    });
  }
}
