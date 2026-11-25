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
import 'dispatch_review_page.dart';
import 'crm_customers_page.dart';
import 'employee_archive_page.dart';
import '../crm/crm_models.dart';

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
  static const tabs = ['日历视图', '任务清单', '下属动态', '统计看板', '客户CRM', '人员档案'];

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

  Future<void> _openDispatchReviews() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => DispatchReviewPage(app: widget.app),
    ));
    if (!mounted) return;
    widget.onRefreshTasks?.call();
    widget.onRefreshIssues?.call();
    setState(() => revision++);
  }

  Widget _companyTab(int i) {
    final active = selected == i;
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: active ? Palette.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('company_tab_$i'),
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              selected = i;
              focusIssuedAfterCreate = false;
            });
            if (i == 2) widget.onRefreshIssues?.call();
            if (i == 1) widget.onRefreshTasks?.call();
          },
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: active ? Palette.primary : Palette.divider),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FittedBox(fit: BoxFit.scaleDown,
              child: Text(tabs[i], maxLines: 1,
                style: TextStyle(
                  color: active ? Colors.white : Palette.deep,
                  fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      // Keep the existing task and subordinate badges when tabs change layout.
      if (i == 1 && widget.unreadTaskIds.isNotEmpty)
        Positioned(top: -7, right: -5,
          child: IgnorePointer(child: TaskUnreadBadge(
            badgeKey: const Key('task_tab_unread_badge'),
            count: widget.unreadTaskIds.length,
          )),
        ),
      if (i == 2 && canViewTeam && widget.subordinateIssueCount > 0)
        Positioned(top: -7, right: -5,
          child: IgnorePointer(child: IssueCountBadge(
            badgeKey: const Key('team_tab_issue_badge'),
            count: widget.subordinateIssueCount,
          )),
        ),
      if (i == 2 && canViewTeam && widget.issueCountUnavailable &&
          widget.subordinateIssueCount == 0)
        const Positioned(top: -7, right: -5,
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
    ]);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            icon: const Icon(Icons.add, size: 22),
            label: const Text('创建任务', style: TextStyle(fontWeight: FontWeight.w800)),
          )
        : null,
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: BusinessHeading(
        title: '公司', subtitle: '日历、任务与团队工作一目了然',
        action: canViewTeam && (selected == 1 || selected == 2)
          ? TextButton(onPressed: _openDispatchReviews,
              child: const Text('派发审核'))
          : selected == 0 ? TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => CalendarPage(app: widget.app, initialMode: 3,
              onTaskViewed: widget.onTaskViewed))),
          child: const Text('甘特图'),
        ) : null,
      )),
      // All company sections remain discoverable without horizontal swiping.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: Padding(
                padding: EdgeInsets.only(right: i == 3 ? 0 : 7),
                child: _companyTab(i),
              )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _companyTab(4),
            )),
            if (CrmAccess.forUser(widget.app.user).employees)
              Expanded(child: _companyTab(5)),
          ]),
        ]),
      ),
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
        3 => StatsPage(key: ValueKey('stats_$revision'), app: widget.app),
        4 => CrmCustomersPage(app: widget.app),
        _ => EmployeeArchivePage(app: widget.app),
      }),
    ]),
  );
}
