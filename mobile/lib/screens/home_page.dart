import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/redesign.dart';
import '../widgets/ui.dart';
import 'calendar_page.dart';
import 'log_detail_page.dart';

class HomePage extends StatefulWidget {
  final AppState app;
  final ValueChanged<int> onTab;
  const HomePage({super.key, required this.app, required this.onTab});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() => _future = _load();
  Future<_HomeData> _load() async {
    final r = widget.app.repo;
    Future<T?> safely<T>(Future<T> Function() get) async { try { return await get(); } catch (_) { return null; } }
    final result = await Future.wait<dynamic>([
      safely(() => r.overview()), safely(() => r.logs()),
      safely(() => r.companyMatters()), safely(() => r.companyImportantTasks()),
    ]);
    return _HomeData(result[0] as Overview?, result[1] as List<WorkLog>?, result[2] as List<CompanyItem>?, result[3] as List<CompanyItem>?);
  }
  void _reload() => setState(_refresh);
  void _calendar() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CalendarPage(app: widget.app)));
  @override Widget build(BuildContext context) {
    final me = widget.app.user!;
    final hour = chinaNow.hour;
    final greeting = hour < 11 ? '早安' : hour < 18 ? '午安' : '晚上好';
    final shortName = me.name.isEmpty ? '伙伴' : me.name;
    return RefreshIndicator(onRefresh: () async { _reload(); await _future; }, child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 19, 22, 38),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PANDORA  /  DAILY WORK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2.1, color: Palette.primary)),
            const SizedBox(height: 7),
            Text('$greeting，$shortName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, letterSpacing: -.8, fontWeight: FontWeight.w900, color: Palette.deep)),
            const SizedBox(height: 3),
            Text('${friendlyDate(todayChina)} · 让每一天都有好进展', style: const TextStyle(color: Palette.muted, fontSize: 12)),
          ])),
          Container(width: 53, height: 53, decoration: BoxDecoration(color: Palette.pastel, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD49A47), size: 29)),
        ]),
        const SizedBox(height: 22),
        _spotlight(),
        const SizedBox(height: 24),
        const TinyLabel(title: '快捷开始'),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: _shortcut(Icons.edit_note_rounded, '写工作日志', '今天的成果', Palette.sage, () => widget.onTab(1))),
          const SizedBox(width: 12),
          Expanded(child: _shortcut(Icons.calendar_month_rounded, '查看日历', '工作时间轴', Palette.pastel, _calendar)),
        ]),
        const SizedBox(height: 24),
        const TinyLabel(title: '今日工作速览'),
        const SizedBox(height: 11),
        FutureBuilder<_HomeData>(future: _future, builder: (context, snapshot) {
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
          final data = snapshot.data!;
          final logs = data.logs?.where((e) => e.logDate == todayChina && e.authorId == me.id).toList() ?? [];
          final myLog = logs.isEmpty ? null : logs.first;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _statBox(data.overview == null ? '—' : '${data.overview!.rate.toStringAsFixed(0)}%', '日志提交率', Icons.pie_chart_rounded, Palette.sage)),
              const SizedBox(width: 11),
              Expanded(child: _statBox(data.overview == null ? '—' : '${data.overview!.unsubmitted}', '待提交人数', Icons.hourglass_top_rounded, Palette.lavender)),
            ]),
            const SizedBox(height: 17),
            StoryCard(color: Palette.deep, child: InkWell(
              onTap: () => myLog == null ? widget.onTab(1) : Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LogDetailPage(app: widget.app, log: myLog))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 25)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(myLog == null ? '今日日志待开启' : '今天的记录', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(myLog == null ? '写下完成的工作，留住今天的收获' : myLog.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC6DEDA), fontSize: 11, height: 1.6)),
                ])),
                const Icon(Icons.arrow_forward_rounded, color: Palette.gold),
              ]),
            )),
            const SizedBox(height: 25),
            const TinyLabel(title: '四大信息面板'),
            const SizedBox(height: 5),
            const Text('重要的事，井然有序', style: TextStyle(color: Palette.muted, fontSize: 12)),
            const SizedBox(height: 13),
            Row(children: [
              Expanded(child: _infoTile('公司事项', '${data.matters?.length ?? '—'} 条信息', Icons.campaign_outlined, const Color(0xFFFFF1DC), () => _itemsSheet('公司重要事项', data.matters))),
              const SizedBox(width: 10),
              Expanded(child: _infoTile('公司任务', '${data.companyTasks?.length ?? '—'} 条信息', Icons.flag_outlined, Palette.lavender, () => _itemsSheet('公司重要任务', data.companyTasks))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _infoTile('我的待办', '管理当前任务', Icons.task_alt_rounded, Palette.sage, () => widget.onTab(2))),
              const SizedBox(width: 10),
              Expanded(child: _infoTile('日志动态', '回顾团队记录', Icons.forum_outlined, const Color(0xFFE8F2F9), () => widget.onTab(1))),
            ]),
            if (data.overview == null || data.logs == null)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('部分信息暂无数据，下拉可重新加载。', style: TextStyle(color: Palette.muted, fontSize: 11))),
          ]);
        }),
      ],
    ));
  }
  Widget _spotlight() => Container(
    height: 190,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0A6763), Color(0xFF178F84), Color(0xFF42B19A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(28)),
    child: Stack(children: [
      Positioned(right: -52, top: -54, child: Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .15), width: 33)))),
      Positioned(right: 15, bottom: -37, child: Icon(Icons.spa_rounded, size: 118, color: Colors.white.withValues(alpha: .14))),
      Positioned.fill(child: Padding(padding: const EdgeInsets.all(23), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(30)), child: const Text('✦  TODAY IN FOCUS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          const Spacer(), const Icon(Icons.north_east_rounded, color: Colors.white),
        ]),
        const Spacer(),
        const Text('把计划，变成今天的进展。', maxLines: 2, style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.3)),
        const SizedBox(height: 8),
        Text('每一次认真记录，都在积累成长', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12)),
      ]))),
    ]),
  );
  Widget _shortcut(IconData icon, String title, String subtitle, Color bg, VoidCallback onTap) => StoryCard(padding: EdgeInsets.zero, child: Material(color: Colors.transparent, child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ColoredIcon(icon: icon, background: bg),
      const SizedBox(height: 13),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.deep, fontSize: 14)),
      const SizedBox(height: 3),
      Row(children: [Expanded(child: Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 11))), const Icon(Icons.arrow_outward_rounded, color: Palette.primary, size: 17)]),
    ])),
  )));
  Widget _statBox(String value, String title, IconData icon, Color bg) => StoryCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [ColoredIcon(icon: icon, background: bg, size: 35), const Spacer(), const Icon(Icons.trending_up_rounded, size: 18, color: Palette.primary)]),
    const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 27, color: Palette.deep, fontWeight: FontWeight.w900)),
    Text(title, style: const TextStyle(fontSize: 11, color: Palette.muted)),
  ]));
  Widget _infoTile(String title, String subtitle, IconData icon, Color bg, VoidCallback onTap) => StoryCard(color: bg, padding: EdgeInsets.zero, child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: SizedBox(height: 125, child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: Palette.deep, size: 24),
    const Spacer(), Text(title, style: const TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 15)),
    const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 10)),
  ]))))));
  void _itemsSheet(String title, List<CompanyItem>? data) {
    if (data == null) { toast(context, '当前信息暂不可用'); return; }
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 26), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 13),
      if (data.isEmpty) const Text('暂无内容') else ...data.take(10).map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.fiber_manual_record_rounded, color: Palette.primary, size: 12), title: Text(item.title), subtitle: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis))),
    ]))));
  }
}
class _HomeData {
  final Overview? overview;
  final List<WorkLog>? logs;
  final List<CompanyItem>? matters, companyTasks;
  const _HomeData(this.overview, this.logs, this.matters, this.companyTasks);
}
