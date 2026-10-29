import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// AI地图入口：现阶段使用现有任务数据绘制状态关系图，不虚构 AI 分析结果。
/// 若需智能知识图谱，需要服务端提供 AI 分析/关联接口。
class TaskMapPage extends StatefulWidget {
  final AppState app;
  const TaskMapPage({super.key, required this.app});
  @override State<TaskMapPage> createState() => _TaskMapPageState();
}
class _TaskMapPageState extends State<TaskMapPage> {
  late Future<List<TaskItem>> _future;
  @override void initState() {super.initState(); _reload();}
  void _reload() => _future = widget.app.repo.taskMap();
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async {setState(_reload); await _future;}, child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 35), children: [
    const Text('PANDORA  /  AI MAP', style: TextStyle(color: Palette.primary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 2)),
    const SizedBox(height: 8), const Text('AI地图', style: TextStyle(color: Palette.deep, fontSize: 30, fontWeight: FontWeight.w900)),
    const SizedBox(height: 5), const Text('任务关系与执行状态可视化', style: TextStyle(color: Palette.muted)),
    const SizedBox(height: 17),
    FutureBuilder<List<TaskItem>>(future: _future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()));
      if (snap.hasError) return ErrorPanel(error: snap.error!, onRetry: () => setState(_reload));
      final tasks = (snap.data ?? []).where((task) => task.source == 'RECEIVED').toList();
      if (tasks.isEmpty) return const EmptyPanel(title: '暂无任务节点', subtitle: '收到的任务将自动加入任务地图');
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(20)), child: Row(children: [
          const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.hub_outlined, color: Colors.white)), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('我的任务节点', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('共 ${tasks.length} 个 · 数据来源：上级派发', style: const TextStyle(color: Color(0xFFC4DFD9), fontSize: 11))])),
        ])),
        const SizedBox(height: 12),
        ...['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'].map((status) {
          final nodes = tasks.where((e) => e.status == status).toList();
          return Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 11, height: 11, decoration: BoxDecoration(color: status == 'COMPLETED' ? Palette.primary : status == 'IN_PROGRESS' ? Palette.gold : Palette.muted, shape: BoxShape.circle)),
              const SizedBox(width: 8), Text('${const {'NOT_STARTED':'待开始','IN_PROGRESS':'进行中','COMPLETED':'已完成'}[status]} · ${nodes.length}', style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 7),
            if (nodes.isEmpty) const Padding(padding: EdgeInsets.only(left: 19), child: Text('暂无节点', style: TextStyle(color: Palette.muted, fontSize: 12)))
            else ...nodes.map((t) => Padding(padding: const EdgeInsets.only(left: 13, bottom: 7), child: Container(
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: Palette.sage, width: 3))),
              child: Padding(padding: const EdgeInsets.only(left: 13), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: ListTile(
                title: Text(t.name, style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)),
                subtitle: Text('截止 ${t.deadline ?? '未设置'}'), trailing: StatusBadge(status: t.status),
              )))))),
          ]));
        }),
        const Text('说明：当前展示为任务状态地图，暂未接入 AI 自动推理或关联分析服务。', style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.5)),
      ]);
    }),
  ]));
}
