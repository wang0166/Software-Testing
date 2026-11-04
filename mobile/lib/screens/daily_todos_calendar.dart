import 'package:flutter/material.dart';
import '../core/daily_todos.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// The user's private month-view todo calendar. No company-task or log APIs.
class DailyTodosCalendar extends StatefulWidget {
  final int userId;
  const DailyTodosCalendar({super.key, required this.userId});
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
    if (oldWidget.userId != widget.userId) _reload();
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
    });
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
      });
    }
  }

  List<DailyTodo> get _selectedItems => _items
      .where((item) => item.date == dayString(_selected)).toList();

  Future<void> _save(List<DailyTodo> updated) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _storage.write(updated);
      if (!mounted) return;
      setState(() => _items = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存每日事项失败：$error')),
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
    String? errorText;
    final result = await showDialog<DailyTodo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? '新增个人事项' : '编辑个人事项'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('日期：${dayString(_selected)}', style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('daily_todo_title_input'), initialValue: draftTitle,
                onChanged: (value) => draftTitle = value,
                maxLength: 100, autofocus: true,
                decoration: InputDecoration(labelText: '事项名称', errorText: errorText),
              ),
              TextFormField(
                initialValue: draftNote, onChanged: (value) => draftNote = value,
                maxLength: 500, maxLines: 3,
                decoration: const InputDecoration(labelText: '补充说明（选填）'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              key: const Key('daily_todo_save_button'),
              onPressed: () {
                if (draftTitle.trim().isEmpty) {
                  setDialogState(() => errorText = '请输入事项名称');
                  return;
                }
                final id = item?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
                Navigator.pop(dialogContext, DailyTodo(
                  id: id, date: dayString(_selected), title: draftTitle.trim(),
                  note: draftNote.trim(), completed: item?.completed ?? false,
                ));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final updated = [..._items];
    updated.removeWhere((e) => e.id == result.id);
    updated.add(result);
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

  Widget _calendar() => LayoutBuilder(builder: (context, bounds) {
    final first = DateTime(_month.year, _month.month, 1);
    final offset = first.weekday - 1; // Monday-first
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final rows = ((offset + days + 6) / 7).floor();
    final cells = rows * 7;
    final itemHeight = (bounds.maxHeight / rows).clamp(29.0, 53.0).toDouble();
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
        final selected = date.year == _selected.year &&
          date.month == _selected.month && date.day == _selected.day;
        final today = DateUtils.isSameDay(date, chinaNow);
        return Material(
          color: selected ? Palette.deep : (today ? const Color(0xFFE1F2EF) : const Color(0xFFF5F7F9)),
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            key: Key('daily_todo_day_$day'),
            borderRadius: BorderRadius.circular(5),
            onTap: () => setState(() => _selected = date),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Palette.deep)),
              if (dayItems.isNotEmpty)
                Container(margin: const EdgeInsets.only(top: 3),
                  width: 5, height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: selected ? Colors.white :
                      (dayItems.every((e) => e.completed) ? Palette.muted : Palette.primary))),
            ]),
          ),
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
      final dayTitleHeight = compact ? 32.0 : 38.0;
      // Header + month navigation + weekday names + grid gap + separator +
      // day title. The grid and day list divide the rest of the height.
      const gapHeight = 5.0;
      const separatorHeight = 1.0;
      final flexible = (height - 2 - headerHeight - monthHeight -
          weekdaysHeight - gapHeight - separatorHeight - dayTitleHeight)
          .clamp(0.0, double.infinity).toDouble();
      final dayListHeight = (flexible * (compact ? 0.35 : 0.30))
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
                  const Expanded(child: Text('每日事项', style: TextStyle(
                    color: Colors.white, fontSize: 15,
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
                  for (final day in ['一', '二', '三', '四', '五', '六', '日'])
                    Expanded(child: Center(child: Text(day,
                      style: const TextStyle(color: Palette.muted,
                        fontWeight: FontWeight.w600, fontSize: 11)))),
                ]),
              ),
            ),
            const SizedBox(height: gapHeight),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _calendar(),
            )),
            const Divider(height: separatorHeight),
            SizedBox(
              height: dayTitleHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(children: [
                  Expanded(child: Text(
                    '${_selected.month}月${_selected.day}日 · ${entries.length} 项',
                    style: const TextStyle(color: Palette.deep,
                      fontSize: 12, fontWeight: FontWeight.w800))),
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
                ? const Align(alignment: Alignment.topLeft, child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    child: Text('当天暂无事项，点击“添加事项”记录个人待办',
                      style: TextStyle(color: Palette.muted, fontSize: 11))))
                : ListView.builder(
                  key: const Key('daily_todo_day_list'),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final item = entries[i];
                    return SizedBox(height: 44, child: Row(children: [
                      Checkbox(
                        key: Key('daily_todo_check_${item.id}'),
                        value: item.completed,
                        onChanged: _saving ? null : (value) =>
                          _save(_items.map((e) => e.id == item.id
                            ? e.copyWith(completed: value ?? false)
                            : e).toList()),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(child: InkWell(
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
                                fontWeight: FontWeight.w700)),
                            if (item.note.isNotEmpty)
                              Text(item.note, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10, color: Palette.muted)),
                          ],
                        ),
                      )),
                      IconButton(
                        tooltip: '删除${item.title}',
                        icon: const Icon(Icons.close, size: 16),
                        color: Palette.muted,
                        visualDensity: VisualDensity.compact,
                        onPressed: _saving ? null : () => _remove(item),
                      ),
                    ]));
                  },
                ),
            ),
          ],
        ]),
      );
    });
  }
}
