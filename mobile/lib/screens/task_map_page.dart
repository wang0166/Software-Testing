import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import '../widgets/business.dart';
import '../widgets/insight_charts.dart';
import '../core/insight_metrics.dart';

/// AI 地图呈现真实任务执行数据，并由服务端汇总授权数据后调用 DeepSeek 生成分析。
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
  Future<AiAnalysis>? _aiFuture;
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

  void _selectSection(int index) {
    if (index == 2 && _aiFuture == null) {
      setState(() {
        section = index;
        _aiFuture = widget.app.repo.aiMapAnalysis();
      });
    } else {
      setState(() => section = index);
    }
  }

  void _loadAi({bool refresh = false}) {
    setState(() => _aiFuture = widget.app.repo.aiMapAnalysis(refresh: refresh));
  }

  Future<void> _refresh() async {
    setState(_reload);
    if (section == 2) _loadAi(refresh: true);
    await _future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),
      children: [
        const BusinessHeading(title: 'AI地图', subtitle: '数据收集 · 任务展示 · AI分析（DeepSeek）'),
        const SizedBox(height: 13),
        Row(children: [
          for(var i = 0; i < 3; i++) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(
              key: ValueKey('ai_map_section_$i'),
              onTap: () => _selectSection(i),
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
        if (section == 2) _aiAnalysis() else FutureBuilder<_TaskMapData>(future: _future, builder: (context, snap) {
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
            const Text('说明：以上为可复核的任务统计；AI 分析由服务端调用 DeepSeek 生成，仅使用本人授权数据。',
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

  Widget _aiAnalysis() {
    final future = _aiFuture;
    if (future == null) return _aiIntro();
    return FutureBuilder<AiAnalysis>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return _aiLoading();
      if (snap.hasError) return Column(children: [
        _aiShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _aiTitle(),
          const SizedBox(height: 10),
          const Text('服务端尚未完成分析。若提示未配置，请联系管理员在后端设置 DEEPSEEK_API_KEY 后重试。',
            style: TextStyle(color: Palette.muted, height: 1.5, fontSize: 12)),
        ])),
        const SizedBox(height: 10),
        ErrorPanel(error: snap.error!, onRetry: () => _loadAi(refresh: true)),
      ]);
      return _aiResult(snap.data!);
    });
  }

  Widget _aiIntro() => _aiShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _aiTitle(),
    const SizedBox(height: 10),
    const Text('服务端只会汇总你权限范围内可见的日志与任务，再把必要摘要发送给 DeepSeek 生成分析；'
        '不会上传其他同事的数据，也不会伪造结论。',
      style: TextStyle(color: Palette.muted, height: 1.5, fontSize: 12)),
    const SizedBox(height: 14),
    SizedBox(width: double.infinity, child: FilledButton.icon(
      onPressed: () => _loadAi(),
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: const Text('生成 AI 分析'))),
  ]));

  Widget _aiLoading() => _aiShell(child: Column(children: [
    _aiTitle(),
    const SizedBox(height: 20),
    const CircularProgressIndicator(),
    const SizedBox(height: 14),
    const Text('正在调用 DeepSeek 分析你授权范围内的数据…',
      textAlign: TextAlign.center,
      style: TextStyle(color: Palette.muted, height: 1.5, fontSize: 12)),
  ]));

  Widget _aiResult(AiAnalysis a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _aiShell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _aiTitle(),
      const SizedBox(height: 12),
      Text(a.summary, style: const TextStyle(
        color: Palette.deep, fontSize: 14, height: 1.6, fontWeight: FontWeight.w600)),
    ])),
    const SizedBox(height: 10),
    _aiBlock('工作亮点', Icons.trending_up_rounded, Palette.primary, a.highlights,
      '未发现可复核的亮点'),
    const SizedBox(height: 10),
    _aiBlock('风险提示', Icons.report_gmailerrorred_rounded, Palette.coral, a.risks,
      '暂未发现明确风险'),
    const SizedBox(height: 10),
    _aiBlock('行动建议', Icons.check_circle_outline_rounded, Palette.deep, a.suggestions,
      '暂无建议'),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Palette.sage.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('基于 ${a.logCount} 条日志 · ${a.taskCount} 项任务 · ${a.dispatchedTaskCount} 项派发任务（${a.range}）',
          style: const TextStyle(color: Palette.deep, fontSize: 11.5,
            fontWeight: FontWeight.w700, height: 1.5)),
        const SizedBox(height: 4),
        Text('${a.model} · 生成于 ${a.generatedAt} · 仅使用本人授权数据，结果仅供工作参考',
          style: const TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
      ])),
    const SizedBox(height: 4),
    Align(alignment: Alignment.centerRight, child: TextButton.icon(
      onPressed: () => _loadAi(refresh: true),
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('重新分析'))),
  ]);

  Widget _aiShell({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, border: Border.all(color: Palette.divider),
      borderRadius: BorderRadius.circular(9)),
    child: child);

  Widget _aiTitle() => const Row(children: [
    Icon(Icons.auto_awesome_outlined, color: Palette.primary, size: 22),
    SizedBox(width: 8),
    Expanded(child: Text('AI 数据分析 · DeepSeek',
      style: TextStyle(color: Palette.deep, fontSize: 17, fontWeight: FontWeight.w900))),
  ]);

  Widget _aiBlock(String title, IconData icon, Color color, List<String> items, String emptyText) =>
    Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Colors.white,
        border: Border.all(color: Palette.divider), borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(
            color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(emptyText, style: const TextStyle(color: Palette.muted, fontSize: 12))
        else
          for(final text in items) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 5), width: 5, height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(
                color: Palette.deep, fontSize: 12.5, height: 1.55))),
            ])),
      ]));

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
