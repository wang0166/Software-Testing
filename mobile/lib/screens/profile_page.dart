import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/redesign.dart';
import '../widgets/ui.dart';
import 'calendar_page.dart';
import 'task_map_page.dart';

class ProfilePage extends StatelessWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});
  @override Widget build(BuildContext context) {
    final user = app.user!;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 19, 22, 32), children: [
      const CanvasHeader(eyebrow: 'PANDORA  /  ME', title: '我的空间', subtitle: '管理工作节奏，也照顾自己的成长', icon: Icons.face_retouching_natural_rounded),
      _identity(user.name, user.roleLabel, user.username),
      const SizedBox(height: 26),
      const TinyLabel(title: '我的工作台'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _feature('工作日历', '任务排期', Icons.calendar_today_rounded, Palette.sage, () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CalendarPage(app: app))))),
        const SizedBox(width: 11),
        Expanded(child: _feature('任务地图', '进度全貌', Icons.account_tree_outlined, Palette.pastel, () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TaskMapPage(app: app))))),
      ]),
      const SizedBox(height: 12),
      StoryCard(child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const ColoredIcon(icon: Icons.shield_moon_outlined, background: Palette.lavender),
        title: const Text('隐私与权限', style: TextStyle(fontWeight: FontWeight.w900, color: Palette.deep)),
        subtitle: const Text('查看当前账号的数据访问规则', style: TextStyle(fontSize: 11, color: Palette.muted)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Palette.muted, size: 16),
        onTap: () => showAboutDialog(context: context, applicationName: '潘多拉智能掌上日志', children: [Text('当前身份：${user.roleLabel}\n账号：${user.username}\n隐私与权限由后端统一控制。')]),
      )),
      const SizedBox(height: 24),
      StoryCard(color: Palette.pastel, child: Row(children: [
        const ColoredIcon(icon: Icons.lightbulb_outline_rounded, color: Color(0xFFB67A30), background: Color(0xFFFFE1AF)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('使用提示', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 3),
          Text(pandoraDemo ? '当前为演示模式，数据仅用于本机演示。' : '当前已连接服务端，权限由账号角色控制。', style: const TextStyle(color: Palette.deep, height: 1.5, fontSize: 11)),
        ])),
      ])),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('退出登录？'), content: const Text('退出后需要重新登录账号。'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认退出')),
        ]));
        if (ok != true) return;
        try { await app.logout(); } catch (e) { if (context.mounted) toast(context, '退出异常：$e'); }
      }, icon: const Icon(Icons.logout_rounded), label: const Text('退出当前账号'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: Palette.deep, side: const BorderSide(color: Palette.divider), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)))),
      const SizedBox(height: 22),
      const Center(child: Text('PANDORA  •  EVERY DAY COUNTS', style: TextStyle(color: Palette.muted, letterSpacing: 1.3, fontWeight: FontWeight.w700, fontSize: 9))),
    ]);
  }
  Widget _identity(String name, String role, String account) => Container(
    height: 207, padding: const EdgeInsets.all(23), clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF102F3A), Color(0xFF1B696A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(29)),
    child: Stack(children: [
      Positioned(right: -67, top: -65, child: Container(width: 195, height: 195, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .11), width: 37)))),
      Positioned(right: 6, bottom: -53, child: Icon(Icons.spa_rounded, size: 116, color: Colors.white.withValues(alpha: .09))),
      Positioned.fill(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PANDORA MEMBERSHIP', style: TextStyle(color: Color(0xFF9DCEC5), letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900)),
        const Spacer(),
        Row(children: [
          CircleAvatar(radius: 30, backgroundColor: const Color(0xFF5AAFA4), child: Text(name.isEmpty ? '我' : name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5), Text('$role  ·  $account', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB8DCD5), fontSize: 11)),
          ])),
        ]),
      ])),
    ]),
  );
  Widget _feature(String title, String subtitle, IconData icon, Color bg, VoidCallback onTap) => StoryCard(color: bg, padding: EdgeInsets.zero, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: Palette.deep, size: 27),
    const SizedBox(height: 21),
    Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Palette.deep))), const Icon(Icons.north_east_rounded, size: 16, color: Palette.deep)]),
    const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 11)),
  ]))));
}
