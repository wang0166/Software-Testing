import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import '../widgets/business.dart';
import '../widgets/insight_charts.dart';
import '../core/insight_metrics.dart';

/// AI 地图当前只呈现真实任务执行数据，不伪造 AI 推理。
/// 员工看收到的任务，具有派发权限的管理者还能看自己派发任务的执行概况。
class TaskMapPage extends StatefulWidget {
  final AppState app;
  const TaskMapPage({super.key, required this.app});

  @override
  State<TaskMapPage> createState() => _TaskMapPageState();
}

class _TaskMapData {
  final List<TaskItem> received;
  final List<DispatchedTask> dispatched;
  final List<WorkLog>? logs; // only server-authorized logs
  int? get logCount => logs?.length;
  const _TaskMapData(this.received, this.dispatched, this.logs);
}

class _TaskMapPageState extends State<TaskMapPage> {
  late Future<_TaskMapData> _future;
  int section = 1; // 默认任务展示，与原任务地图习惯保持一致

  bool get _canDispatch => const ['TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER']
      .contains(widget.app.user?.role);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _load();

  Future<_TaskMapData> _load() async {
    List<TaskItem> received = const [];
    List<DispatchedTask> dispatched = const [];
    Object? receivedError;
    Object? sentError;
    List<WorkLog>? authorizedLogs;
    try { authorizedLogs = await widget.app.repo.logs(); }
    catch (_) { /* Data collection will indicate unavailability. */ }

    try {
      // 后端 task-map 接口遵循当前登录用户的权限范围。
      received = (await widget.app.repo.taskMap())
          .where((t) => t.source == 'RECEIVED')
          .toList();
    } catch (e) {
      receivedError = e;
    }
    if (_canDispatch) {
      try {
        dispatched = await widget.app.repo.dispatchedTasks();
      } catch (e) {
        sentError = e;
      }
    }
    if (received.isEmpty && dispatched.isEmpty && authorizedLogs == null) {
      if (receivedError != null) throw receivedError;
      if (sentError != null) throw sentError;
    }
    return _TaskMapData(received, dispatched, authorizedLogs);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),
      children: [
        const BusinessHeading(title: 'AI地图', subtitle: '数据收集 · 任务展示 · AI数据分析（预留）'),
        const SizedBox(height: 13),
        Row(children: [
          for(var i = 0; i < 3; i++) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(
              key: ValueKey('ai_map_section_$i'),
              onTap: () => setState(() => section = i),
              borderRadius: BorderRadius.circular(8),
              child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: section == i ? Palette.deep : Colors.white,
                  border: Border.all(color: section == i ? Palette.deep : Palette.divider),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(const ['数据收集','任务展示','AI分析'][i],
                  style: TextStyle(color: section == i ? Colors.white : Palette.deep,
                    fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 17),
        if (section == 2) _aiPlaceholder() else FutureBuilder<_TaskMapData>(future: _future, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return ErrorPanel(error: snap.error!, onRetry: () => setState(_reload));
          }
          final data = snap.data!;
          if (section == 0) return _collection(data);
          // Even an empty task dataset should render the three requested
          // chart modules with their honest zero-data states.
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(data),
            const SizedBox(height: 15),
            _analyticsDashboard(data),
            const SizedBox(height: 22),
            if (data.received.isEmpty && data.dispatched.isEmpty)
              const EmptyPanel(title: '暂无可展示的任务',
                subtitle: '当前账号未获得任务记录；统计图保留空数据状态。'),
            if (data.received.isNotEmpty) ...[
              const Text('我收到的任务', style: TextStyle(color: Palette.deep,
                  fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 9),
              ...['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'].map((status) {
                final nodes = data.received.where((t) => t.status == status).toList();
                return Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 11, height: 11,
                        decoration: BoxDecoration(
                          color: status == 'COMPLETED' ? Palette.primary
                              : status == 'IN_PROGRESS' ? Palette.gold : Palette.muted,
                          shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('${const {
                        'NOT_STARTED': '待开始',
                        'IN_PROGRESS': '进行中',
                        'COMPLETED': '已完成'
                      }[status]} · ${nodes.length}',
                        style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 7),
                    if (nodes.isEmpty)
                      const Padding(padding: EdgeInsets.only(left: 19),
                        child: Text('暂无节点', style: TextStyle(color: Palette.muted, fontSize: 12)))
                    else
                      ...nodes.take(24).map((t) => Padding(
                        padding: const EdgeInsets.only(left: 13, bottom: 7),
                        child: Container(
                          decoration: const BoxDecoration(border: Border(
                            left: BorderSide(color: Palette.sage, width: 3))),
                          child: Padding(padding: const EdgeInsets.only(left: 13),
                            child: Material(color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              child: ListTile(
                                title: Text(t.name, style: const TextStyle(
                                  color: Palette.deep, fontWeight: FontWeight.w800)),
                                subtitle: Text('${taskTypeLabel(t.taskType)} · 截止 ${t.deadline ?? '未设置'}'),
                                trailing: StatusBadge(status: t.status),
                              )),
                          ),
                        ),
                      )),
                  ],
                ));
              }),
            ],
            if (data.dispatched.isNotEmpty) ...[
              const Text('我派发的任务', style: TextStyle(color: Palette.deep,
                  fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              const Text('按照真实任务接收人数与完成情况展示',
                  style: TextStyle(color: Palette.muted, fontSize: 12)),
              const SizedBox(height: 10),
              ...data.dispatched.take(25).map(_sentCard),
              if (data.dispatched.length > 25)
                Padding(padding: const EdgeInsets.all(8),
                  child: Text('共 ${data.dispatched.length} 项，仅展示最近的前 25 项',
                    style: const TextStyle(color: Palette.muted, fontSize: 12))),
            ],
            const SizedBox(height: 10),
            const Text('说明：以上为可复核的任务统计；AI 推理服务尚未接入。',
                style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
          ]);
        }),
      ],
    ),
  );

  Widget _collection(_TaskMapData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(data), const SizedBox(height: 15),
      _sourceCard('授权工作日志', data.logCount == null ? '暂不可读取' : '${data.logCount} 条',
        '仅统计当前用户获得授权的日志；不会自动对外发送正文。'),
      const SizedBox(height: 10),
      _sourceCard('接收任务', '${data.received.length} 项', '从已接入的任务接口取得的任务记录。'),
      const SizedBox(height: 10),
      _sourceCard('派发任务', '${data.dispatched.length} 项',
        '仅统计本人有权查看的已派发任务。'),
      const SizedBox(height: 15),
      InsightChartCard(
        key: const Key('keyword_extraction_panel'),
        title: '工作关键词提取与量化统计',
        subtitle: '根据授权日志内容、接收任务标题与详情计算频次及规则分数',
        child: data.logs == null
          ? const Text('日志暂不可读取；请检查接口权限及网络连接',
              style: TextStyle(color: Palette.muted, fontSize: 12))
          : WorkKeywordPanel(keywords: extractWorkKeywords(
              logs: data.logs!, tasks: data.received)),
      ),
    ],
  );

  /// Three chart types requested in the client's prototype. All values are
  /// computed from the user's authorized task data, never hardcoded examples.
  Widget _analyticsDashboard(_TaskMapData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InsightChartCard(
        key: const Key('task_completion_table'),
        title: '计划与任务 · 完成率表格',
        subtitle: '派发任务按完成/接收人数计算；收到的任务按实际状态展示，进行中不伪造进度百分比',
        child: TaskCompletionTable(
          received: data.received,
          dispatched: data.dispatched,
        ),
      ),
      const SizedBox(height: 12),
      InsightChartCard(
        key: const Key('task_importance_pie'),
        title: '重要占比 · 任务紧急程度饼图',
        subtitle: '统计当前登录账号收到的任务；紧急和普通按服务端返回的紧急程度区分',
        child: TaskUrgencyPie(tasks: data.received),
      ),
      const SizedBox(height: 12),
      InsightChartCard(
        key: const Key('task_vertical_chart'),
        title: '数据分析竖图 · 任务状态分布',
        subtitle: '按照待开始、进行中、已完成三个状态统计收到的任务数量',
        child: TaskStatusBarChart(tasks: data.received),
      ),
    ],
  );

  Widget _sourceCard(String name, String count, String note) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: Palette.divider), borderRadius: BorderRadius.circular(9)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(name, style: const TextStyle(color: Palette.deep,
          fontSize: 14, fontWeight: FontWeight.w900))),
        Text(count, style: const TextStyle(color: Palette.primary,
          fontSize: 17, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 5),
      Text(note, style: const TextStyle(color: Palette.muted, fontSize: 11)),
    ]),
  );

  Widget _aiPlaceholder() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(9)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.auto_awesome_outlined, color: Palette.primary, size: 22),
        SizedBox(width: 8),
        Expanded(child: Text('AI 数据分析 · 接口预留',
          style: TextStyle(color: Palette.deep, fontSize: 17, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 10),
      const Text('分析服务尚未接入，不会生成虚假的结论、MBTI 推断或职业发展建议。',
        style: TextStyle(color: Palette.muted, height: 1.5, fontSize: 12)),
      const Divider(height: 25),
      for(final item in [
        '结合关键词进行更深入的语义与风险分析',
        '任务趋势与执行风险分析',
        '基于用户授权资料的个性化工作建议',
      ]) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.lock_clock_outlined, color: Palette.muted, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(item, style: const TextStyle(
            color: Palette.deep, fontWeight: FontWeight.w600, fontSize: 12))),
          const Text('待接入', style: TextStyle(color: Palette.muted, fontSize: 11)),
        ])),
      const SizedBox(height: 12),
      const Text('后续应由服务端控制权限、脱敏、用户同意、模型调用与结果审计。',
        style: TextStyle(color: Palette.muted, fontSize: 11)),
    ]),
  );

  Widget _header(_TaskMapData data) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('任务状态总览',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('收到 ${data.received.length} 项 · 派发 ${data.dispatched.length} 项',
            style: const TextStyle(color: Color(0xFFC5D4E1), fontSize: 12)),
        ],
      )),
    ]),
  );

  Widget _sentCard(DispatchedTask task) {
    final progress = task.assigneeCount == 0
        ? 0.0
        : (task.completedCount / task.assigneeCount).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.name, style: const TextStyle(
                color: Palette.deep, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text('接收 ${task.assigneeCount} 人 · 完成 ${task.completedCount} 人',
              style: const TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(height: 9),
            LinearProgressIndicator(value: progress, minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              color: Palette.primary, backgroundColor: Palette.sage),
            const SizedBox(height: 6),
            Text('截止 ${task.deadline}',
                style: const TextStyle(color: Palette.muted, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
