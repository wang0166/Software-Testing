import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'password_change_page.dart';

/// 头像支持拍照/相册；目前仅保存在本机，跨设备同步仍需后台接口。
class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  String mbtiType = '';
  static const mbtiOptions = <String>[
    '', 'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];
  @override void initState() {super.initState(); _loadMbti();}
  Future<void> _loadMbti() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) setState(() => mbtiType = prefs.getString('pandora_mbti_${widget.app.user!.id}') ?? widget.app.user?.mbtiType ?? '');
  }
  Future<void> _editMbti() async {
    var selection = mbtiOptions.contains(mbtiType) ? mbtiType : '';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) => AlertDialog(
        title: const Text('我的 MBTI（选填）'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('仅用于个人展示，不构成职业能力判断；暂存本机，后续需后端授权同步。',
            style: TextStyle(fontSize: 12, color: Palette.muted)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: selection, isExpanded: true,
            items: mbtiOptions.map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? '暂不填写' : v))).toList(),
            onChanged: (value) => refresh(() => selection = value ?? '')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    ));
    if(confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString('pandora_mbti_${widget.app.user!.id}', selection);
    if(mounted) {
      if(ok) setState(() => mbtiType = selection);
      toast(context, ok ? 'MBTI 信息已保存在本机' : '保存失败，请重试');
    }
  }
  Future<void> _avatar() async {
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('拍照'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('从相册选择'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        const SizedBox(height: 9),
      ]),
    ));
    if (source == null || !mounted) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 480, maxHeight: 480, imageQuality: 72);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024 * 1024) {if (mounted) toast(context, '图片过大，请更换小于1MB的头像'); return;}
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('pandora_local_avatar_${widget.app.user!.id}', base64Encode(bytes));
      if (!mounted) return;
      toast(context, saved ? '头像已保存在本机，其他设备暂不同步' : '头像保存失败');
      if (saved) setState(() {});
    } catch (e) {if (mounted) toast(context, '选择头像失败：$e');}
  }
  Future<void> _change() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => PasswordChangePage(repo: widget.app.repo, demo: pandoraDemo),
      ));
      if (mounted && changed == true) {
        toast(context, pandoraDemo ? '演示密码已修改（本次运行有效）' : '密码修改成功');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('设置')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('账号与安全', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Palette.deep)),
      const SizedBox(height: 6), const Text('管理个人头像和登录安全信息', style: TextStyle(color: Palette.muted)),
      const SizedBox(height: 20),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: Column(children: [
        ListTile(leading: const Icon(Icons.add_a_photo_outlined, color: Palette.primary), title: const Text('更换头像'), subtitle: const Text('支持拍照 / 相册 · 暂存本机'), trailing: const Icon(Icons.chevron_right), onTap: _avatar),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.badge_outlined, color: Palette.primary),
          title: const Text('MBTI 类型（选填）'),
          subtitle: Text(mbtiType.isEmpty ? '未填写 · 仅本机保存' : '$mbtiType · 仅本机保存'),
          trailing: const Icon(Icons.chevron_right), onTap: _editMbti),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.lock_reset_rounded, color: Palette.primary), title: const Text('修改密码'), subtitle: const Text('验证原密码 · 实时强度检测'), trailing: const Icon(Icons.chevron_right), onTap: busy ? null : _change),
      ])),
      const SizedBox(height: 17),
      const Text('安全说明：修改密码需验证原密码，新密码必须通过强度校验，无需管理员审批。忘记密码请使用登录页的找回入口。', style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.5)),
    ]));
  }
}
