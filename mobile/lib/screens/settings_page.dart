import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// 头像支持拍照/相册；目前仅保存在本机，跨设备同步仍需后台接口。
class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  String status = '正在读取';
  String mbtiType = '';
  static const mbtiOptions = <String>[
    '', 'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];
  @override void initState() {super.initState(); _load(); _loadMbti();}
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
  Future<void> _load() async {
    try {
      final state = await widget.app.repo.passwordChangeStatus();
      if (mounted) setState(() => status = state);
    } catch (e) {if (mounted) setState(() => status = '暂不可用：$e');}
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
  Future<void> _request() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.app.repo.requestPasswordChange();
      if (mounted) toast(context, '修改密码申请已提交，等待管理员审核');
      await _load();
    } catch (e) {if (mounted) toast(context, '申请失败：$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> _change() async {
    String first = ''; String second = '';
    try {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('设置新密码'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (v) => first = v, obscureText: true, decoration: const InputDecoration(labelText: '新密码（至少 8 位）')),
          const SizedBox(height: 10), TextField(onChanged: (v) => second = v, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认修改'))],
      ));
      if (ok != true || !mounted) return;
      if (first.length < 8 || first != second) {toast(context, '密码至少 8 位且两次输入必须一致'); return;}
      setState(() => busy = true);
      await widget.app.repo.completePasswordChange(first);
      if (mounted) {toast(context, '密码修改成功'); await _load();}
    } catch (e) {if (mounted) toast(context, '密码修改失败：$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  @override Widget build(BuildContext context) {
    final approved = status == 'APPROVED';
    final waiting = status == 'PENDING';
    return Scaffold(appBar: AppBar(title: const Text('设置')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('账号与安全', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Palette.deep)),
      const SizedBox(height: 6), const Text('管理个人头像和登录安全信息', style: TextStyle(color: Palette.muted)),
      const SizedBox(height: 20),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: Column(children: [
        ListTile(leading: const Icon(Icons.add_a_photo_outlined, color: Palette.primary), title: const Text('更换头像'), subtitle: const Text('支持拍照 / 相册 · 暂存本机'), trailing: const Icon(Icons.chevron_right), onTap: _avatar),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.badge_outlined, color: Palette.primary),
          title: const Text('MBTI 类型（选填）'),
          subtitle: Text(mbtiType.isEmpty ? '未填写 · 仅本机保存' : '$mbtiType · 仅本机保存'),
          trailing: const Icon(Icons.chevron_right), onTap: _editMbti),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.lock_reset_rounded, color: Palette.primary), title: const Text('修改密码'), subtitle: const Text('需要管理员审核后才能设置新密码'), trailing: const Icon(Icons.chevron_right), onTap: waiting || busy ? null : approved ? _change : _request),
      ])),
      const SizedBox(height: 17),
      Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Palette.mutedBlue, borderRadius: BorderRadius.circular(11), border: Border.all(color: Palette.divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('密码申请状态', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(switch(status) {'NONE' => '尚未申请', 'PENDING' => '待管理员审核', 'APPROVED' => '已批准，请点击上方修改密码', 'REJECTED' => '申请被驳回，可以重新申请', _ => status}, style: const TextStyle(color: Palette.deep)),
        const SizedBox(height: 7), TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 17), label: const Text('刷新审核状态')),
      ])),
      const SizedBox(height: 12),
      const Text('安全说明：仅在管理员批准申请后允许设置新密码。服务端需要强制验证审批状态，并存储密码哈希。', style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.5)),
    ]));
  }
}
