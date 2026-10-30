import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/redesign.dart';
import '../widgets/ui.dart';
import '../widgets/business.dart';

class StatsPage extends StatefulWidget {
  final AppState app;
  const StatsPage({super.key, required this.app});
  @override State<StatsPage> createState() => _StatsPageState();
}
class _StatsPageState extends State<StatsPage> {
  int _days = 7;
  late Future<_StatsData> _future;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() {
    _future = _load();
  }
  Future<_StatsData> _load() async {
    final r = widget.app.repo;
    final values = await Future.wait<dynamic>([r.overview(), r.trend(_days), r.unsubmitted()]);
    return _StatsData(values[0] as Overview, values[1] as List<TrendPoint>, values[2] as List<String>);
  }
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async { setState(_refresh); await _future; }, child: ListView(
    padding: const EdgeInsets.fromLTRB(22, 19, 22, 110),
    children: [
      const BusinessHeading(title: '统计看板', subtitle: '组织范围内的日志提交与工作趋势'),
      const SizedBox(height: 15),
      FutureBuilder<_StatsData>(future: _future, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(55), child: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return ErrorPanel(error: snap.error!, onRetry: () => setState(_refresh));
        final d = snap.data!, o = d.overview;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _hero(o),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _metric('应提交', o.expected, Palette.lavender)),
            const SizedBox(width: 10),
            Expanded(child: _metric('已提交', o.submitted, Palette.sage)),
            const SizedBox(width: 10),
            Expanded(child: _metric('待提交', o.unsubmitted, Palette.pastel)),
          ]),
          const SizedBox(height: 28),
          Row(children: [const Expanded(child: TinyLabel(title: '日志趋势')), _selector(7), const SizedBox(width: 7), _selector(30)]),
          const SizedBox(height: 11),
          StoryCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const ColoredIcon(icon: Icons.bar_chart_rounded, background: Palette.sage, size: 38), const SizedBox(width: 10), Expanded(child: Text('最近 $_days 天的提交节奏', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Palette.deep)))]),
            const SizedBox(height: 18),
            TrendBars(points: d.trend, maxBars: _days),
            const SizedBox(height: 12),
            const Text('数据根据当前账号的可见范围汇总', style: TextStyle(color: Palette.muted, fontSize: 10)),
          ])),
          const SizedBox(height: 28),
          TinyLabel(title: '待提交成员', action: '${d.unsubmitted.length} 人'),
          const SizedBox(height: 12),
          StoryCard(child: d.unsubmitted.isEmpty
            ? const EmptyPanel(title: '今日全部完成', subtitle: '团队的每一份努力都已记录', icon: Icons.celebration_rounded)
            : Column(children: [for (var i = 0; i < d.unsubmitted.length; i++) Column(children: [
                if (i > 0) const Divider(height: 19),
                Row(children: [
                  CircleAvatar(backgroundColor: Palette.pastel, radius: 19, child: Text(d.unsubmitted[i].isEmpty ? '—' : d.unsubmitted[i].substring(0, 1), style: const TextStyle(color: Color(0xFFB8844B), fontWeight: FontWeight.w900))),
                  const SizedBox(width: 12), Expanded(child: Text(d.unsubmitted[i], style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.deep))),
                  const Pill(text: '等待提交', color: Color(0xFFAD783A), background: Palette.pastel),
                ]),
              ])])),
        ]);
      }),
    ],
  ));
  Widget _selector(int days) => InkWell(onTap: () => setState(() { _days = days; _refresh(); }), borderRadius: BorderRadius.circular(9), child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(color: _days == days ? Palette.deep : Colors.white, borderRadius: BorderRadius.circular(9)),
    child: Text('$days天', style: TextStyle(color: _days == days ? Colors.white : Palette.muted, fontSize: 11, fontWeight: FontWeight.w800)),
  ));
  Widget _hero(Overview o) => Container(
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Palette.deep, Color(0xFF1C465C)]), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('今日团队效率', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.rate.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 43, fontWeight: FontWeight.w900, letterSpacing: -2)),
          const Text('今日日志提交率', style: TextStyle(color: Color(0xFFC5D4E1), fontSize: 12)),
          const SizedBox(height: 12),
          Text('${o.submitted} / ${o.expected} 人已完成记录', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ])),
        SizedBox(width: 98, height: 98, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: (o.rate / 100).clamp(0, 1).toDouble(), strokeWidth: 11, strokeCap: StrokeCap.round, backgroundColor: Colors.white.withValues(alpha: .19), color: Palette.gold)),
          const Text('日志', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ]),
    ]),
  );
  Widget _metric(String label, int value, Color bg) => StoryCard(color: bg, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 11), child: Column(children: [
    Text('$value', style: const TextStyle(color: Palette.deep, fontSize: 24, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Palette.muted, fontSize: 10)),
  ]));
}
class _StatsData {
  final Overview overview;
  final List<TrendPoint> trend;
  final List<String> unsubmitted;
  const _StatsData(this.overview, this.trend, this.unsubmitted);
}
