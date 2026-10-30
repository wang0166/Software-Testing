import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

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
  const _TaskMapData(this.received, this.dispatched);
}

class _TaskMapPageState extends State<TaskMapPage> {
  late Future<_TaskMapData> _future;

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
    if (received.isEmpty && dispatched.isEmpty) {
      if (receivedError != null) throw receivedError;
      if (sentError != null) throw sentError;
    }
    return _TaskMapData(received, dispatched);
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
        const Text('PANDORA  /  AI MAP',
            style: TextStyle(color: Palette.primary, fontWeight: FontWeight.w800,
                fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text('AI地图',
            style: TextStyle(color: Palette.deep, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('任务关系与执行状态可视化', style: TextStyle(color: Palette.muted)),
        const SizedBox(height: 17),
        FutureBuilder<_TaskMapData>(future: _future, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return ErrorPanel(error: snap.error!, onRetry: () => setState(_reload));
          }
          final data = snap.data!;
          if (data.received.isEmpty && data.dispatched.isEmpty) {
            return const EmptyPanel(
              title: '暂无可展示的任务',
              subtitle: '直属上级派发或自己向下级派发任务后，任务将在这里展示。下拉可刷新。',
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(data),
            const SizedBox(height: 17),
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
                                subtitle: Text('截止 ${t.deadline ?? '未设置'}'),
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
            const Text('说明：当前为真实任务状态地图，尚未接入 AI 自动推理服务。',
                style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
          ]);
        }),
      ],
    ),
  );

  Widget _header(_TaskMapData data) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const CircleAvatar(backgroundColor: Colors.white24,
          child: Icon(Icons.hub_outlined, color: Colors.white)),
      const SizedBox(width: 12),
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
