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
  String mbtiType = '';
  @override void initState() {super.initState(); _loadAvatar();}
  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        avatar = prefs.getString('pandora_local_avatar_${widget.app.user!.id}');
        mbtiType = prefs.getString('pandora_mbti_${widget.app.user!.id}') ?? widget.app.user?.mbtiType ?? '';
      });
    }
  }
  @override Widget build(BuildContext context) {
    final me = widget.app.user!;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 32), children: [
      const Text('PANDORA  /  ACCOUNT', style: TextStyle(color: Palette.primary, fontWeight: FontWeight.w700, letterSpacing: 1.1, fontSize: 10)),
      const SizedBox(height: 8), const Text('个人中心', style: TextStyle(color: Palette.deep, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(14)), child: Row(children: [
        CircleAvatar(radius: 34, backgroundColor: Colors.white24, backgroundImage: avatar == null ? null : MemoryImage(base64Decode(avatar!)), child: avatar == null ? Text(me.name.isEmpty ? '我' : me.name.substring(0,1), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)) : null),
        const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(me.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)), const SizedBox(height: 5),
          Text('${me.roleLabel}  ·  ${me.username}', style: const TextStyle(color: Color(0xFFC5D4E1), fontSize: 12)),
          const SizedBox(height: 7),
          Text('MBTI：${mbtiType.isEmpty ? '未填写' : mbtiType}', style: const TextStyle(
            color: Color(0xFFB2E7E0), fontSize: 12, fontWeight: FontWeight.w800)),
        ])),
      ])),
      const SizedBox(height: 20), const Text('个人设置', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 9),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: Column(children: [
        ListTile(leading: const Icon(Icons.settings_outlined, color: Palette.primary), title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('更换头像 · 密码审核 · 账号安全'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsPage(app: widget.app)));
          _loadAvatar();
        }),
        const Divider(height: 1, indent: 18, endIndent: 18),
        ListTile(leading: const Icon(Icons.shield_outlined, color: Palette.primary), title: const Text('数据与权限', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('当前账号可访问的组织范围'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showAboutDialog(context: context, applicationName: '智能掌上日志系统（潘多拉 Pandora）', children: [Text('角色：${me.roleLabel}\n部门：${me.departmentId ?? '公司级'}\n团队：${me.teamId ?? '部门级'}\n服务端负责校验所有数据访问权限。')]))
      ])),
      const SizedBox(height: 17),
      Material(color: Palette.mutedBlue, borderRadius: BorderRadius.circular(10), child: const Padding(padding: EdgeInsets.all(15), child: Text('日志与点评遵循组织权限；任务派发申请需经审核，修改密码也需管理员批准。', style: TextStyle(color: Palette.deep, height: 1.5, fontSize: 12)))),
      const SizedBox(height: 19),
      OutlinedButton.icon(onPressed: () async {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('退出当前账号？'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出'))]));
        if (ok != true) return;
        try {await widget.app.logout();} catch (e) {if (context.mounted) toast(context, '$e');}
      }, icon: const Icon(Icons.logout_rounded), label: const Text('退出登录')),
    ]);
  }
}
