import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'daily_todos_calendar.dart';
import 'task_progress_page.dart';

/// 客户 2026-11 调整：首页只保留事件纪、任务看板、个人每日事项。
/// 每日事项是独立 Todo，不属于公司任务，也不进入工作日志。
class HomePage extends StatefulWidget {
  final AppState app;
  final ValueChanged<int> onTab;
  final ValueChanged<int>? onTaskViewed;
  const HomePage({super.key, required this.app, required this.onTab,
    this.onTaskViewed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _load();
  }

  Future<_HomeData> _load() async {
    Future<List<T>?> safe<T>(Future<List<T>> Function() action) async {
      try { return await action(); } catch (_) { return null; }
    }
    final results = await Future.wait<dynamic>([
      safe(widget.app.repo.companyMatters),
      safe(() => widget.app.repo.tasks(personal: false)),
    ]);
    return _HomeData(results[0] as List<CompanyItem>?,
      results[1] as List<TaskItem>?);
  }

  String _taskSummary(TaskItem task) {
    final deadline = task.deadline;
    final deadlineLabel = deadline == null || deadline.isEmpty
      ? '未设置截止' : '截止 ${deadline.replaceFirst('T', ' ')}';
    final urgent = task.urgency == 'URGENT' ? '紧急 · ' : '';
    return '${task.status == 'COMPLETED' ? '已完成' : '进行中'} · $urgent$deadlineLabel';
  }

  Future<void> _openReceivedTask(TaskItem task) async {
    widget.onTaskViewed?.call(task.id);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => TaskProgressPage(app: widget.app, task: task),
    ));
    if (mounted) setState(_refresh);
  }

  void _showEvent(CompanyItem item) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(item.title),
      content: SingleChildScrollView(child: Text(item.content.isEmpty ? '暂无详细说明' : item.content)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_HomeData>(
    future: _future,
    builder: (context, snap) {
      final data = snap.data;
      final loading = snap.connectionState != ConnectionState.done;
      final matters = data?.matters?.take(10).map((m) => _TileRecord(
        m.title, m.content, onTap: () => _showEvent(m),
      )).toList();
      // /tasks/received gives assignments of *this executor*. It must never
      // expose unapproved requests or unrelated employees' tasks.
      final received = data?.receivedTasks?.map((task) => _TileRecord(
        task.name,
        _taskSummary(task),
        onTap: () => _openReceivedTask(task),
      )).toList();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('首页', style: TextStyle(color: Palette.deep,
                    fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('企业事件 · 我的接收任务 · 个人每日事项',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Palette.muted, fontSize: 10)),
                ],
              )),
              TextButton(
                key: const Key('home_refresh'),
                onPressed: loading ? null : () => setState(_refresh),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 5),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 240, child: Row(children: [
            Expanded(child: _HomeTile(
              key: const Key('event_history_panel'),
              title: '事件纪', order: '01', records: matters,
              loading: loading,
            )),
            const SizedBox(width: 9),
            Expanded(child: _HomeTile(
              key: const Key('task_board_panel'),
              title: '任务看板', order: '02', records: received,
              loading: loading, countSuffix: '项',
            )),
          ])),
          const SizedBox(height: 10),
          SizedBox(height: 675, child: DailyTodosCalendar(
            key: ValueKey('daily_todo_${widget.app.user?.id ?? 0}'),
            userId: widget.app.user?.id ?? 0,
          )),
        ]),
      );
    },
  );
}

class _TileRecord {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _TileRecord(this.title, this.subtitle, {this.onTap});
}

class _HomeTile extends StatefulWidget {
  final String title;
  final String order;
  final List<_TileRecord>? records;
  final bool loading;
  final String countSuffix;
  const _HomeTile({super.key, required this.title, required this.order,
    required this.records, required this.loading, this.countSuffix = '/10'});

  @override State<_HomeTile> createState() => _HomeTileState();
}

class _HomeTileState extends State<_HomeTile> {
  final ScrollController _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.divider),
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 57),
            padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
            color: Palette.deep,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.order, style: const TextStyle(
                color: Color(0xFF65D2C4), fontSize: 12, fontWeight: FontWeight.w800,
              )),
              const SizedBox(width: 5),
              Expanded(child: Text(widget.title, maxLines: 2,
                overflow: TextOverflow.ellipsis, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 12, height: 1.3,
                ))),
              if (records != null) Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text('${records.length}${widget.countSuffix}', style: const TextStyle(
                  color: Color(0xFF9ADCD4), fontSize: 10,
                )),
              ),
            ]),
          ),
          Expanded(
            child: widget.loading && records == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : records == null || records.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: Align(alignment: Alignment.topLeft,
                          child: Text(records == null ? '数据加载失败，请刷新' : '暂无可查看的信息',
                            style: const TextStyle(fontSize: 12, color: Palette.muted))),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        thickness: 2.5,
                        radius: const Radius.circular(3),
                        child: ListView.separated(
                          key: PageStorageKey('home_tile_${widget.order}'),
                          controller: _scroll,
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(9, 4, 8, 4),
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Palette.divider,
                          ),
                          itemBuilder: (context, index) {
                            final row = records[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: row.onTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${index + 1}'.padLeft(2, '0'),
                                        style: const TextStyle(color: Palette.primary,
                                          fontSize: 10, fontWeight: FontWeight.w900)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(row.title, maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12,
                                              height: 1.3, fontWeight: FontWeight.w700,
                                              color: Palette.deep)),
                                          if (row.subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(row.subtitle, maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10,
                                                color: Palette.muted)),
                                          ],
                                        ],
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  final List<CompanyItem>? matters;
  final List<TaskItem>? receivedTasks;
  const _HomeData(this.matters, this.receivedTasks);
}
