import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/business.dart';
import '../widgets/issue_count_badge.dart';
import '../widgets/task_unread_badge.dart';
import 'tasks_page.dart';
import 'calendar_page.dart';
import 'stats_page.dart';
import 'subordinates_page.dart';
import 'dispatch_page.dart';

/// 默认日历；任务列表、下属动态、统计为同级视图。
class ViewPage extends StatefulWidget {
  final AppState app;
  final int subordinateIssueCount;
  final bool issueCountUnavailable;
  final VoidCallback? onRefreshIssues;
  final VoidCallback? onRefreshTasks;
  final Set<int> unreadTaskIds;
  final ValueChanged<int>? onTaskViewed;
  const ViewPage({super.key, required this.app,
    this.subordinateIssueCount = 0, this.issueCountUnavailable = false,
    this.onRefreshIssues,
    this.onRefreshTasks, this.unreadTaskIds = const <int>{}, this.onTaskViewed});
  @override State<ViewPage> createState() => _ViewPageState();
}
class _ViewPageState extends State<ViewPage> {
  bool get canViewTeam => const ['FOUNDER','DEPT_MANAGER','TEAM_LEADER'].contains(widget.app.user?.role);
  int selected = 0;
  int revision = 0;
  bool openingCreate = false;
  bool focusIssuedAfterCreate = false;
  static const tabs = ['日历视图', '任务清单', '下属动态', '统计看板'];

  Future<void> _createTask() async {
    if (openingCreate) return;
    setState(() => openingCreate = true);
    try {
      final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => DispatchPage(app: widget.app),
      ));
      if (mounted && submitted == true) {
        widget.onRefreshIssues?.call();
        widget.onRefreshTasks?.call();
        setState(() {
          revision++;
          selected = 1; // Show the newly submitted request in my issued records.
          focusIssuedAfterCreate = true;
        });
      }
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
        title: '公司', subtitle: '日历、任务与团队工作一目了然',
        action: selected == 0 ? TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => CalendarPage(app: widget.app, initialMode: 3,
              onTaskViewed: widget.onTaskViewed))),
          child: const Text('甘特图'),
        ) : null,
      )),
      SizedBox(height: 47, child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < tabs.length; i++) Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 10, 0),
            child: Stack(clipBehavior: Clip.none, children: [
              ChoiceChip(
                label: Text(tabs[i]),
                selected: selected == i,
                showCheckmark: false,
                selectedColor: Palette.deep, backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected == i ? Colors.white : Palette.deep,
                  fontWeight: FontWeight.w700, fontSize: 12),
                side: BorderSide(color: selected == i ? Palette.deep : Palette.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                onSelected: (_) {
                  setState(() {
                    selected = i;
                    focusIssuedAfterCreate = false;
                  });
                  if (i == 2) widget.onRefreshIssues?.call();
                  if (i == 1) widget.onRefreshTasks?.call();
                },
              ),
              // 子页标签分别显示独立角标；底部五大导航绝不显示数字。
              if (i == 1 && widget.unreadTaskIds.isNotEmpty)
                Positioned(
                  top: -5, right: -6,
                  child: IgnorePointer(child: TaskUnreadBadge(
                    badgeKey: const Key('task_tab_unread_badge'),
                    count: widget.unreadTaskIds.length,
                  )),
                ),
              if (i == 2 && canViewTeam && widget.subordinateIssueCount > 0)
                Positioned(
                  top: -5, right: -6,
                  child: IgnorePointer(child: IssueCountBadge(
                    badgeKey: const Key('team_tab_issue_badge'),
                    count: widget.subordinateIssueCount,
                  )),
                ),
              // If the server cannot calculate the count, display a warning,
              // never a false red "0" and never a fabricated issue number.
              if (i == 2 && canViewTeam && widget.issueCountUnavailable &&
                  widget.subordinateIssueCount == 0)
                const Positioned(
                  top: -5, right: -6,
                  child: Tooltip(
                    message: '下属问题数量暂无法更新，请进入下属动态重试',
                    child: CircleAvatar(
                      key: Key('team_tab_issue_unavailable'),
                      radius: 10, backgroundColor: Color(0xFFC48626),
                      child: Text('!', style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      )),
      const SizedBox(height: 8),
      Expanded(child: switch (selected) {
        0 => CalendarPage(key: ValueKey('calendar_$revision'),
              app: widget.app, embedded: true,
              onTaskViewed: widget.onTaskViewed),
        1 => TasksPage(key: ValueKey('tasks_${revision}_$focusIssuedAfterCreate'),
              app: widget.app, initiallyIssued: focusIssuedAfterCreate,
              unreadTaskIds: widget.unreadTaskIds,
              onTaskViewed: widget.onTaskViewed),
        2 => SubordinatesPage(key: ValueKey('team_$revision'), app: widget.app,
              onIssueChanged: widget.onRefreshIssues),
        _ => StatsPage(key: ValueKey('stats_$revision'), app: widget.app),
      }),
    ]),
  );
}
