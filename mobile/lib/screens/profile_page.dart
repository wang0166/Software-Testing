import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  final AppState app;
  const ProfilePage({super.key, required this.app});
  @override State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  String? avatar;
  @override void initState() {super.initState(); _loadAvatar();}
  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => avatar = prefs.getString('pandora_local_avatar_${widget.app.user!.id}'));
  }
  @override Widget build(BuildContext context) {
    final me = widget.app.user!;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
      const Text('MY  PANDORA', style: TextStyle(color: Palette.primary, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11)),
      const SizedBox(height: 8), const Text('个人中心', style: TextStyle(color: Palette.deep, fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Palette.deep, Palette.primary]), borderRadius: BorderRadius.circular(25)), child: Row(children: [
        CircleAvatar(radius: 34, backgroundColor: Colors.white24, backgroundImage: avatar == null ? null : MemoryImage(base64Decode(avatar!)), child: avatar == null ? Text(me.name.isEmpty ? '我' : me.name.substring(0,1), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)) : null),
        const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(me.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)), const SizedBox(height: 5),
          Text('${me.roleLabel}  ·  ${me.username}', style: const TextStyle(color: Color(0xFFE0F5EF), fontSize: 12)),
        ])),
      ])),
      const SizedBox(height: 24), const Text('个人设置', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 9),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(20), child: Column(children: [
        ListTile(leading: const Icon(Icons.settings_outlined, color: Palette.primary), title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('更换头像 · 密码审核 · 账号安全'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsPage(app: widget.app)));
          _loadAvatar();
        }),
        const Divider(height: 1, indent: 18, endIndent: 18),
        ListTile(leading: const Icon(Icons.shield_outlined, color: Palette.primary), title: const Text('数据与权限', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('当前账号可访问的组织范围'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showAboutDialog(context: context, applicationName: '智能掌上日志系统（潘多拉 Pandora）', children: [Text('角色：${me.roleLabel}\n部门：${me.departmentId ?? '公司级'}\n团队：${me.teamId ?? '部门级'}\n服务端负责校验所有数据访问权限。')]))
      ])),
      const SizedBox(height: 17),
      Material(color: Palette.pastel, borderRadius: BorderRadius.circular(17), child: const Padding(padding: EdgeInsets.all(15), child: Text('日志与点评遵循组织层级和直属上级权限；未经批准不得修改密码。', style: TextStyle(color: Palette.deep, height: 1.5, fontSize: 12)))),
      const SizedBox(height: 19),
      OutlinedButton.icon(onPressed: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('退出当前账号？'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出'))]));
        if (ok != true) return;
        try {await widget.app.logout();} catch (e) {if (context.mounted) toast(context, '$e');}
      }, icon: const Icon(Icons.logout_rounded), label: const Text('退出登录')),
    ]);
  }
}
