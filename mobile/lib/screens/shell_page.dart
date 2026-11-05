import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/task_read_tracker.dart';
import 'home_page.dart';
import 'view_page.dart';
import 'logs_page.dart';
import 'task_map_page.dart';
import 'profile_page.dart';

/// 主导航名称和顺序固定为：导图、视图、日志、AI地图、我的。
/// 在 Shell 层轮询两个独立计数，角标仅放在工作视图的子页标签上。
class ShellPage extends StatefulWidget {
  final AppState app;
  const ShellPage({super.key, required this.app});
  @override State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> with WidgetsBindingObserver {
  int _index = 0;
  int _issueCount = 0;
  bool _issueCountUnavailable = false;
  bool _loadingIssues = false;
  bool _loadingTasks = false;
  Set<int> _unreadTaskIds = <int>{};
  final Set<int> _openedThisSession = <int>{};
  late final TaskReadTracker _taskReads;
  Timer? _badgeRefreshTimer;

  bool get _canViewTeam => const ['FOUNDER', 'DEPT_MANAGER', 'TEAM_LEADER']
      .contains(widget.app.user?.role);
  bool get _canUseTasks => widget.app.user?.canUseTasks ?? false;

  static const labels = ['导图', '视图', '日志', 'AI地图', '我的'];
  static const icons = [
    Icons.account_tree_outlined, Icons.calendar_month_outlined, Icons.article_outlined,
    Icons.schema_outlined, Icons.person_outline_rounded,
  ];
  static const selectedIcons = [
    Icons.account_tree_rounded, Icons.calendar_month_rounded, Icons.article_rounded,
    Icons.schema_rounded, Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskReads = TaskReadTracker(widget.app.user?.id ?? 0);
    _refreshAllBadges();
    _startBadgePolling();
  }

  void _startBadgePolling() {
    if (_badgeRefreshTimer != null || (!_canViewTeam && !_canUseTasks)) return;
    // 前台轮询。未读任务仅记录在本机；下属问题仍由后端权限范围决定。
    _badgeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshAllBadges();
    });
  }

  void _refreshAllBadges() {
    _refreshIssueCount();
    _refreshTaskCount();
  }

  Future<void> _refreshTaskCount() async {
    if (!_canUseTasks || _loadingTasks) return;
    _loadingTasks = true;
    try {
      final tasks = await widget.app.repo.tasks(personal: false);
      final unread = await _taskReads.unreadIds(tasks);
      unread.removeAll(_openedThisSession);
      if (mounted && !setEquals(_unreadTaskIds, unread)) {
        setState(() => _unreadTaskIds = unread);
      }
    } catch (_) {
      // 网络错误不会把已显示的未读数错误清零。
    } finally {
      _loadingTasks = false;
    }
  }

  void _onTaskViewed(int assignmentId) {
    if (assignmentId <= 0) return;
    _openedThisSession.add(assignmentId);
    if (_unreadTaskIds.contains(assignmentId)) {
      setState(() => _unreadTaskIds = {..._unreadTaskIds}..remove(assignmentId));
    }
    unawaited(_taskReads.markViewed(assignmentId).catchError((Object _) {
      // 本地写入失败不伪造同步成功；下一次拉取可再次核对。
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBadgePolling();
      _refreshAllBadges();
    } else {
      _badgeRefreshTimer?.cancel();
      _badgeRefreshTimer = null;
    }
  }

  Future<void> _refreshIssueCount() async {
    if (!_canViewTeam || _loadingIssues) return;
    _loadingIssues = true;
    try {
      final rows = await widget.app.repo.subordinatesTaskOverview();
      final updated = rows.fold<int>(0, (count, row) => count + row.visibleIssueCount);
      if (mounted && (_issueCount != updated || _issueCountUnavailable)) {
        setState(() {
          _issueCount = updated;
          _issueCountUnavailable = false;
        });
      }
    } catch (_) {
      // Never treat an API failure as a genuine "zero issues" result.
      // Preserve a prior count and show an explicit unavailable indicator.
      if (mounted && !_issueCountUnavailable) {
        setState(() => _issueCountUnavailable = true);
      }
    } finally {
      _loadingIssues = false;
    }
  }

  @override
  void dispose() {
    _badgeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(app: widget.app, onTab: (i) {
        setState(() => _index = i);
        if (i == 1) _refreshAllBadges();
      }),
      ViewPage(app: widget.app,
        subordinateIssueCount: _issueCount,
        issueCountUnavailable: _issueCountUnavailable,
        onRefreshIssues: _refreshIssueCount,
        unreadTaskIds: _unreadTaskIds, onTaskViewed: _onTaskViewed,
        onRefreshTasks: _refreshTaskCount),
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
                onTap: () {
                  setState(() => _index = i);
                  if (i == 1) _refreshAllBadges();
                },
                child: Semantics(
                  button: true, selected: _index == i,
                  label: labels[i],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 3, width: 34, color: _index == i ? Palette.primary : Colors.transparent),
                      const SizedBox(height: 10),
                      SizedBox(width: 28, height: 25, child: Center(
                        child: Icon(
                          _index == i ? selectedIcons[i] : icons[i],
                          color: _index == i ? Palette.deep : Palette.muted, size: 22,
                        ),
                      )),
                      const SizedBox(height: 5),
                      Text(labels[i], maxLines: 1, style: TextStyle(
                        color: _index == i ? Palette.deep : Palette.muted,
                        fontSize: 11,
                        fontWeight: _index == i ? FontWeight.w800 : FontWeight.w500,
                      )),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              )),
          ]),
        )),
      ),
    );
  }
}
