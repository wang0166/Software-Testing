import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import 'home_page.dart';
import 'logs_page.dart';
import 'tasks_page.dart';
import 'stats_page.dart';
import 'profile_page.dart';

class ShellPage extends StatefulWidget {
  final AppState app;
  const ShellPage({super.key,required this.app});
  @override State<ShellPage> createState()=>_ShellPageState();
}
class _ShellPageState extends State<ShellPage> {
  int _current=0;
  @override Widget build(BuildContext context) {
    final tabs=<Widget>[
      HomePage(app:widget.app,onTab:(i)=>setState(()=>_current=i)),
      LogsPage(app:widget.app),
      TasksPage(app:widget.app),
      StatsPage(app:widget.app),
      ProfilePage(app:widget.app),
    ];
    return Scaffold(
      body:SafeArea(child:tabs[_current]),
      bottomNavigationBar:NavigationBar(
        backgroundColor:Colors.white,
        indicatorColor:Palette.sage,
        shadowColor:Palette.deep.withValues(alpha:.04),
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex:_current,
        onDestinationSelected:(i)=>setState(()=>_current=i),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard_rounded),label:'概览'),
          NavigationDestination(icon:Icon(Icons.menu_book_outlined),selectedIcon:Icon(Icons.menu_book_rounded),label:'日志'),
          NavigationDestination(icon:Icon(Icons.checklist_outlined),selectedIcon:Icon(Icons.checklist_rounded),label:'任务'),
          NavigationDestination(icon:Icon(Icons.bar_chart_rounded),selectedIcon:Icon(Icons.query_stats_rounded),label:'统计'),
          NavigationDestination(icon:Icon(Icons.person_outline_rounded),selectedIcon:Icon(Icons.person_rounded),label:'我的'),
        ],
      ),
    );
  }
}
