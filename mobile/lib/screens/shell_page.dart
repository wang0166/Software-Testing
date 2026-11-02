import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import 'home_page.dart';
import 'view_page.dart';
import 'logs_page.dart';
import 'task_map_page.dart';
import 'profile_page.dart';

/// 主导航名称和顺序固定为：导图、视图、日志、AI地图、我的。
class ShellPage extends StatefulWidget {
  final AppState app;
  const ShellPage({super.key, required this.app});
  @override State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  static const labels = ['导图', '视图', '日志', 'AI地图', '我的'];
  static const icons = [
    Icons.account_tree_outlined, Icons.calendar_month_outlined, Icons.article_outlined,
    Icons.schema_outlined, Icons.person_outline_rounded,
  ];
  static const selectedIcons = [
    Icons.account_tree_rounded, Icons.calendar_month_rounded, Icons.article_rounded,
    Icons.schema_rounded, Icons.person_rounded,
  ];
  @override Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(app: widget.app, onTab: (i) => setState(() => _index = i)),
      ViewPage(app: widget.app),
      LogsPage(app: widget.app),
      TaskMapPage(app: widget.app),
      ProfilePage(app: widget.app),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Palette.divider)),
        ),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
          child: Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(child: InkWell(
                key: Key('nav_$i'),
                onTap: () => setState(() => _index = i),
                child: Semantics(button: true, selected: _index == i, label: labels[i], child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 3, width: 34, color: _index == i ? Palette.primary : Colors.transparent),
                    const SizedBox(height: 10),
                    Icon(_index == i ? selectedIcons[i] : icons[i],
                      color: _index == i ? Palette.deep : Palette.muted, size: 22),
                    const SizedBox(height: 5),
                    Text(labels[i], maxLines: 1, style: TextStyle(
                      color: _index == i ? Palette.deep : Palette.muted,
                      fontSize: 11,
                      fontWeight: _index == i ? FontWeight.w800 : FontWeight.w500,
                    )),
                    const SizedBox(height: 5),
                  ],
                )),
              )),
          ]),
        )),
      ),
    );
  }
}
