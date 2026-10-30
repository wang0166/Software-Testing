import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'log_detail_page.dart';

/// 导图首页：四大信息面板优先，不再让统计、欢迎卡片挤占首屏。
class HomePage extends StatefulWidget {
  final AppState app;
  final ValueChanged<int> onTab;
  const HomePage({super.key, required this.app, required this.onTab});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late Future<_Panels> _future;
  @override void initState() {super.initState(); _reload();}
  void _reload() => _future = _load();
  Future<_Panels> _load() async {
    // 独立卡片可用性：一个接口失败不影响其他信息面板。
    Future<List<T>?> safe<T>(Future<List<T>> Function() call) async {
      try {return await call();} catch (_) {return null;}
    }
    final values = await Future.wait<dynamic>([
      safe(() => widget.app.repo.companyMatters()),
      safe(() => widget.app.repo.companyImportantTasks()),
      safe(() => widget.app.repo.logs()),
    ]);
    return _Panels(values[0] as List<CompanyItem>?, values[1] as List<CompanyItem>?, values[2] as List<WorkLog>?);
  }

  @override Widget build(BuildContext context) {
    final me = widget.app.user!;
    return RefreshIndicator(onRefresh: () async {setState(_reload); await _future;}, child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 32),
      children: [
        const Text('PANDORA  /  INFORMATION MAP', style: TextStyle(color: Palette.primary, letterSpacing: 2.1, fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(height: 8),
        const Text('信息导图', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: Palette.deep)),
        const SizedBox(height: 4),
        const Text('四大信息面板 · 核心信息一目了然', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 22),
        FutureBuilder<_Panels>(future: _future, builder: (context, snap) {
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()));
          final p = snap.data!;
          final own = p.logs?.where((l) => l.authorId == me.id).take(10).toList();
          final recent = p.logs?.take(10).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _panel('公司10大重要事项展示', '01 / COMPANY', Icons.campaign_rounded, Palette.pastel,
                  _count(p.matters), () => _showCompany('公司10大重要事项展示', p.matters))),
              const SizedBox(width: 12),
              Expanded(child: _panel('公司10大任务派发', '02 / DISPATCH', Icons.outbox_rounded, Palette.sage,
                  _count(p.tasks), () => _showCompany('公司10大任务派发', p.tasks))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _panel('个人10大信息展示', '03 / PERSONAL', Icons.person_pin_rounded, const Color(0xFFEAF0FB),
                  _count(own), () => _showLogs('个人10大信息展示', own))),
              const SizedBox(width: 12),
              Expanded(child: _panel('日志展示', '04 / JOURNAL', Icons.menu_book_rounded, const Color(0xFFF7EAE8),
                  _count(recent), () => _showLogs('日志展示', recent))),
            ]),
            const SizedBox(height: 23),
            const Text('最新信息', style: TextStyle(color: Palette.deep, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            if (p.logs == null) const _Hint('日志暂时无法加载，请下拉刷新。')
            else if (p.logs!.isEmpty) const _Hint('暂无可查看的日志。')
            else ...p.logs!.take(3).map((log) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(
              color: Colors.white, borderRadius: BorderRadius.circular(18), child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LogDetailPage(app: widget.app, log: log))),
              leading: CircleAvatar(backgroundColor: Palette.sage, child: Text(log.authorName.isEmpty ? '记' : log.authorName.substring(0, 1), style: const TextStyle(color: Palette.deep))),
              title: Text('${log.authorName} · ${log.logDate}', style: const TextStyle(color: Palette.deep, fontSize: 13, fontWeight: FontWeight.w800)),
              subtitle: Text(log.content, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded, color: Palette.primary),
            )))),
            const SizedBox(height: 5),
            OutlinedButton.icon(onPressed: () => widget.onTab(2), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('进入日志')),
          ]);
        }),
      ],
    ));
  }
  String _count(List<dynamic>? values) => values == null ? '读取失败' : '${values.take(10).length} 条信息';
  Widget _panel(String title, String label, IconData icon, Color accent, String count, VoidCallback onTap) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(23), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(23), child: Container(
    height: 187, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Palette.divider), borderRadius: BorderRadius.circular(23)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Palette.primary, size: 23)), const Spacer(), const Icon(Icons.north_east_rounded, color: Palette.muted, size: 18)]),
      const Spacer(),
      Text(label, style: const TextStyle(color: Palette.primary, letterSpacing: .8, fontSize: 9, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(title, maxLines: 2, style: const TextStyle(color: Palette.deep, fontSize: 14, fontWeight: FontWeight.w900, height: 1.35)),
      const SizedBox(height: 6), Text(count, style: const TextStyle(color: Palette.muted, fontSize: 11)),
    ])),
  ));
  void _showCompany(String title, List<CompanyItem>? items) => _sheet(title,
    items?.take(10).map((i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(i.title), subtitle: Text(i.content, maxLines: 4, overflow: TextOverflow.ellipsis))).toList());
  void _showLogs(String title, List<WorkLog>? items) => _sheet(title,
    items?.take(10).map((i) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${i.authorName} · ${i.logDate}'), subtitle: Text(i.content, maxLines: 3, overflow: TextOverflow.ellipsis), onTap: () {Navigator.pop(context);Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LogDetailPage(app: widget.app, log: i)));})).toList());
  void _sheet(String title, List<Widget>? tiles) => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => SafeArea(child: FractionallySizedBox(heightFactor: .73, child: ListView(padding: const EdgeInsets.all(22), children: [
    Text(title, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 12),
    if (tiles == null) const Text('当前接口不可用，请稍后重试。') else if (tiles.isEmpty) const Text('暂无信息') else ...tiles,
  ]))));
}
class _Panels {
  final List<CompanyItem>? matters, tasks;
  final List<WorkLog>? logs;
  const _Panels(this.matters, this.tasks, this.logs);
}
class _Hint extends StatelessWidget {
  final String value;
  const _Hint(this.value);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: Text(value, style: const TextStyle(color: Palette.muted)));
}
