import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import 'tasks_page.dart';
import 'calendar_page.dart';
import 'stats_page.dart';

/// 视图容纳任务清单、日历和统计；均沿用原有业务接口。
class ViewPage extends StatefulWidget {
  final AppState app;
  const ViewPage({super.key, required this.app});
  @override State<ViewPage> createState() => _ViewPageState();
}
class _ViewPageState extends State<ViewPage> {
  int selected = 0;
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 15, 20, 8), child: Row(children: [
      const Expanded(child: Text('工作视图', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 23))),
      TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CalendarPage(app: widget.app, initialMode: 3))), icon: const Icon(Icons.view_timeline_rounded, size: 18), label: const Text('甘特图')),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
      for (var i = 0; i < 3; i++) Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: InkWell(onTap: () => setState(() => selected = i), borderRadius: BorderRadius.circular(13), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: selected == i ? Palette.primary : Colors.white, borderRadius: BorderRadius.circular(13)),
        alignment: Alignment.center, child: Text(const ['任务清单', '日历视图', '统计看板'][i], style: TextStyle(fontSize: 12, color: selected == i ? Colors.white : Palette.deep, fontWeight: FontWeight.w800)),
      )))),
    ])),
    const SizedBox(height: 8),
    Expanded(child: selected == 0 ? TasksPage(app: widget.app) : selected == 1 ? CalendarPage(app: widget.app, embedded: true) : StatsPage(app: widget.app)),
  ]);
}
