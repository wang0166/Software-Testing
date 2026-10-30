import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import 'tasks_page.dart';
import 'calendar_page.dart';
import 'stats_page.dart';
import 'subordinates_page.dart';
import 'dispatch_page.dart';

/// 默认日历；任务列表、下属动态、统计为同级视图。
class ViewPage extends StatefulWidget {
  final AppState app;
  const ViewPage({super.key, required this.app});
  @override State<ViewPage> createState() => _ViewPageState();
}
class _ViewPageState extends State<ViewPage> {
  int selected = 0;
  int revision = 0;
  bool openingCreate = false;
  static const tabs = ['日历视图', '任务清单', '下属动态', '统计看板'];

  Future<void> _createTask() async {
    if (openingCreate) return;
    setState(() => openingCreate = true);
    try {
      final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => DispatchPage(app: widget.app),
      ));
      if (mounted && submitted == true) setState(() => revision++);
    } finally {
      if (mounted) setState(() => openingCreate = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Palette.paper,
    // The primary task action remains discoverable on the default calendar,
    // received-task ledger, subordinate overview and statistics alike.
    floatingActionButton: (widget.app.user?.canUseTasks ?? false)
        ? FloatingActionButton.extended(
            key: const Key('view_create_task'),
            heroTag: 'pandora_view_create_task',
            onPressed: openingCreate ? null : _createTask,
            backgroundColor: Palette.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.add, size: 22),
            label: const Text('创建任务', style: TextStyle(fontWeight: FontWeight.w800)),
          )
        : null,
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: BusinessHeading(
        title: '工作视图', subtitle: '日历、任务与团队工作一目了然',
        action: selected == 0 ? TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => CalendarPage(app: widget.app, initialMode: 3))),
          child: const Text('甘特图'),
        ) : null,
      )),
      SizedBox(height: 47, child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < tabs.length; i++) Padding(
            padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text(tabs[i]), selected: selected == i,
              showCheckmark: false,
              selectedColor: Palette.deep, backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected == i ? Colors.white : Palette.deep,
                fontWeight: FontWeight.w700, fontSize: 12),
              side: BorderSide(color: selected == i ? Palette.deep : Palette.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              onSelected: (_) => setState(() => selected = i),
            ),
          ),
        ],
      )),
      const SizedBox(height: 8),
      Expanded(child: switch (selected) {
        0 => CalendarPage(key: ValueKey('calendar_$revision'),
              app: widget.app, embedded: true),
        1 => TasksPage(key: ValueKey('tasks_$revision'), app: widget.app),
        2 => SubordinatesPage(key: ValueKey('team_$revision'), app: widget.app),
        _ => StatsPage(key: ValueKey('stats_$revision'), app: widget.app),
      }),
    ]),
  );
}
