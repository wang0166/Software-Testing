import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import 'home_page.dart';
import 'logs_page.dart';
import 'tasks_page.dart';
import 'stats_page.dart';
import 'profile_page.dart';

/// Floating editorial dock; the selected destination is a teal capsule,
/// unlike the original uniform Material3 NavigationBar.
class ShellPage extends StatefulWidget {
  final AppState app;
  const ShellPage({super.key, required this.app});
  @override State<ShellPage> createState() => _ShellPageState();
}
class _ShellPageState extends State<ShellPage> {
  int _current = 0;
  static const icons = <IconData>[
    Icons.dashboard_customize_outlined,
    Icons.menu_book_outlined,
    Icons.check_circle_outline_rounded,
    Icons.auto_graph_rounded,
    Icons.person_outline_rounded,
  ];
  static const activeIcons = <IconData>[
    Icons.dashboard_customize_rounded,
    Icons.menu_book_rounded,
    Icons.check_circle_rounded,
    Icons.auto_graph_rounded,
    Icons.person_rounded,
  ];
  static const labels = ['首页', '日志', '任务', '数据', '我的'];
  @override Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomePage(app: widget.app, onTab: (i) => setState(() => _current = i)),
      LogsPage(app: widget.app),
      TasksPage(app: widget.app),
      StatsPage(app: widget.app),
      ProfilePage(app: widget.app),
    ];
    return Scaffold(
      body: SafeArea(child: tabs[_current]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Palette.deep.withValues(alpha: .075), blurRadius: 25, offset: const Offset(0, -7))]),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          child: Row(children: [for (var i = 0; i < 5; i++) Expanded(child: Semantics(
            button: true, selected: _current == i,
            label: labels[i],
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => setState(() => _current = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: _current == i ? Palette.deep : Colors.transparent, borderRadius: BorderRadius.circular(17)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_current == i ? activeIcons[i] : icons[i], color: _current == i ? Colors.white : Palette.muted, size: 22),
                  const SizedBox(height: 3),
                  Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: _current == i ? FontWeight.w900 : FontWeight.w600, color: _current == i ? Colors.white : Palette.muted)),
                ]),
              ),
            ),
          ))],),
        )),
      ),
    );
  }
}
