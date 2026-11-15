import 'package:flutter/material.dart';
import '../core/daily_todos.dart';
import '../core/holiday_calendar.dart';
import '../data/holiday_calendar_service.dart';
import '../widgets/holiday_calendar_widgets.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// The user's private month-view todo calendar. No company-task or log APIs.
class DailyTodosCalendar extends StatefulWidget {
  final int userId;
  final HolidayCalendarService? holidayService;
  const DailyTodosCalendar({super.key, required this.userId,
    this.holidayService});
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
    if (oldWidget.userId != widget.userId) _reload();
    if (oldWidget.holidayService != widget.holidayService) _fetchHolidays();
  }

  Future<void> _reload() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final loaded = await _storage.read();
      if (!mounted) return;
      setState(() { _items = loaded; _loading = false; });
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
    _fetchHolidays();
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
      _fetchHolidays();
    }
  }

  List<DailyTodo> get _selectedItems => _items
      .where((item) => item.date == dayString(_selected)).toList();

  Future<bool> _save(List<DailyTodo> updated) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await _storage.write(updated);
      if (!mounted) return false;
      setState(() => _items = updated);
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

  Future<void> _edit([DailyTodo? item]) async {
    var draftTitle = item?.title ?? '';
    var draftNote = item?.note ?? '';
    var draftColor = item?.colorValue ?? DailyTodoColors.defaultColor;
    TimeOfDay? start = _parseTime(item?.startTime);
    TimeOfDay? end = _parseTime(item?.endTime);
    String? errorText;
    String? timeError;
    final result = await showDialog<DailyTodo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
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
                  Text('日期：${item?.date ?? dayString(_selected)}',
                    style: const TextStyle(color: Palette.muted)),
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
                  if (!DailyTodo.validTimeRange(startText, endText)) {
                    setDialogState(() => timeError = '请设置完整时间段，结束时间必须晚于开始时间');
                    return;
                  }
                  final id = item?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString();
                  Navigator.pop(dialogContext, DailyTodo(
                    id: id, date: item?.date ?? dayString(_selected),
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
    await _save(updated);
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
    final updated = [..._items];
    updated[index] = updated[index].copyWith(date: targetDate);
    final saved = await _save(updated);
    if (saved && mounted) {
      final parsed = DateTime.tryParse(targetDate);
      if (parsed != null) setState(() => _selected = parsed);
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

  Widget _calendar() => LayoutBuilder(builder: (context, bounds) {
    final first = DateTime(_month.year, _month.month, 1);
    final offset = first.weekday - 1; // Monday-first
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final rows = ((offset + days + 6) / 7).floor();
    final cells = rows * 7;
    final itemHeight = ((bounds.maxHeight - (rows - 1) * 2) / rows)
      .clamp(29.0, 85.0).toDouble();
    final dateHeight = itemHeight < 35 ? 21.0 : 25.0;
    final labelGap = itemHeight < 35 ? 0.0 : 2.0;
    return GridView.builder(
      key: const Key('daily_todo_month_grid'),
      physics: itemHeight * rows > bounds.maxHeight
        ? const ClampingScrollPhysics()
        : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, mainAxisExtent: itemHeight,
        mainAxisSpacing: 2, crossAxisSpacing: 2,
      ),
      itemCount: cells,
      itemBuilder: (ctx, index) {
        final n = index - offset + 1;
        if (n <= 0 || n > days) return const SizedBox.shrink();
        final date = DateTime(_month.year, _month.month, n);
        final day = dayString(date);
        final dayItems = _items.where((e) => e.date == day).toList();
        final holiday = _holidayView?.on(date);
        final showFestival = holiday != null &&
            holiday.festivalLabel.isNotEmpty && itemHeight >= 57;
        // Reserve space for date, festivals and the '+N' overflow marker.
        final remainingHeight = itemHeight - 4 - dateHeight - labelGap -
            (showFestival ? 13 : 0);
        var visible = dayItems.length < 2 ? dayItems.length : 2;
        while (visible > 0 && visible * 16 +
            (dayItems.length > visible ? 12 : 0) > remainingHeight) {
          visible--;
        }
        final hidden = dayItems.length - visible;
        final showMore = hidden > 0 && visible * 16 + 12 <= remainingHeight;
        final selected = DateUtils.isSameDay(date, _selected);
        final today = DateUtils.isSameDay(date, chinaNow);
        return DragTarget<String>(
          key: Key('daily_todo_drop_$day'),
          onWillAcceptWithDetails: (details) => !_saving && _items.any(
            (item) => item.id == details.data && item.date != day),
          onAcceptWithDetails: (details) => _moveToDate(details.data, day),
          builder: (ctx, candidates, rejected) {
            final hovering = candidates.isNotEmpty;
            return Material(
              color: hovering ? const Color(0xFFFFE4EE)
                  : selected ? const Color(0xFFFFF1F7)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: hovering ? const Color(0xFFD9749A)
                      : selected ? const Color(0xFFEAB0C9)
                      : const Color(0xFFF5EAF0),
                  width: hovering ? 1.7 : 0.7,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('daily_todo_day_$day'),
                onTap: () => setState(() => _selected = date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: dateHeight, child: Stack(children: [
                        Center(child: Container(
                          height: dateHeight, width: dateHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFE991B1)
                              : today ? const Color(0xFFFFE4D3)
                              : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text('$n', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : Palette.deep,
                          )),
                        )),
                        if (holiday?.dayTypeLabel.isNotEmpty == true)
                          Positioned(right: 0, top: 0,
                            child: HolidayDayBadge(day: holiday)),
                      ])),
                      if (showFestival)
                        SizedBox(height: 13,
                          child: HolidayFestivalLabel(day: holiday)),
                      SizedBox(height: labelGap),
                      for (final item in dayItems.take(visible))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: LongPressDraggable<String>(
                            key: Key('daily_todo_drag_calendar_${item.id}'),
                            data: item.id,
                            maxSimultaneousDrags: _saving ? 0 : 1,
                            feedback: _dragFeedback(item),
                            childWhenDragging: const SizedBox(height: 14),
                            child: Container(
                              height: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: item.completed
                                  ? const Color(0xFFE7E7EC)
                                  : Color(item.colorValue),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(item.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9, height: 1.15,
                                  color: item.completed
                                    ? Palette.muted : Palette.deep,
                                  fontWeight: FontWeight.w700,
                                  decoration: item.completed
                                    ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showMore)
                        Text('+$hidden', textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD577A2), fontSize: 10,
                            height: 1.15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  });

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
      final dayListHeight = (flexible * (compact ? 0.35 : 0.34))
          .clamp(0.0, compact ? 56.0 : 188.0).toDouble();

      return Container(
        key: const Key('daily_todo_panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFD),
          border: Border.all(color: const Color(0xFFF1D8E4)),
          borderRadius: BorderRadius.circular(20),
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
                  IconButton(
                    onPressed: () => _moveMonth(-1), tooltip: '上个月',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34, height: 34),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.chevron_left),
                  ),
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
                  IconButton(
                    onPressed: () => _moveMonth(1), tooltip: '下个月',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34, height: 34),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.chevron_right),
                  ),
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
                        color: day == '周六' || day == '周日'
                          ? const Color(0xFFD17C9E) : Palette.muted,
                        fontWeight: FontWeight.w700, fontSize: 11)))),
                ]),
              ),
            ),
            const SizedBox(height: gapHeight),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _calendar(),
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
                        const Flexible(child: Text('长按事项可拖到其他日期，拖动右侧手柄可排序',
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
                    onReorderItem: _reorderDay,
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
                                    Text(item.startTime == null
                                        ? (item.note.isEmpty ? '全天' : '全天 · ${item.note}')
                                        : (item.note.isEmpty
                                          ? item.timeLabel
                                          : '${item.timeLabel} · ${item.note}'),
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
