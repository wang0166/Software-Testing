import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/mock_repository.dart';
import '../widgets/ui.dart';

class LoginPage extends StatefulWidget {
  final AppState app;
  const LoginPage({super.key, required this.app});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool obscure = true, busy = false;
  @override void dispose() {username.dispose(); password.dispose(); super.dispose();}
  Future<void> _login() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {await widget.app.login(username.text.trim(), password.text);}
    catch (e) {if (mounted) toast(context, '$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> _forgotPassword() async {
    String account = username.text.trim();
    try {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('忘记密码'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('输入登录账号，向系统管理员申请重置密码。'), const SizedBox(height: 12),
          TextFormField(initialValue: account, onChanged: (text) => account = text, decoration: const InputDecoration(labelText: '登录账号')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('提交申请'))],
      ));
      if (ok != true || !mounted) return;
      if (account.trim().isEmpty) {toast(context, '请输入账号'); return;}
      await widget.app.repo.requestPasswordReset(account.trim());
      if (mounted) toast(context, pandoraDemo ? '本机演示申请已记录，实际审核须接入服务端' : '申请已提交，请联系系统管理员审核');
    } catch (e) {if (mounted) toast(context, '申请失败：$e');}
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(23, 28, 23, 28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 73, height: 73, decoration: BoxDecoration(color: Palette.primary, borderRadius: BorderRadius.circular(23)), child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 38))),
      const SizedBox(height: 17), const Center(child: Text('智能掌上日志系统', style: TextStyle(color: Palette.deep, fontSize: 26, fontWeight: FontWeight.w900))),
      const SizedBox(height: 3), const Center(child: Text('PANDORA  ·  潘多拉', style: TextStyle(color: Palette.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2))),
      const SizedBox(height: 26),
      Container(padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)), child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('欢迎回来', style: TextStyle(color: Palette.deep, fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3), const Text('登录后进入你的工作空间', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 22), const Text('登录账号', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)), const SizedBox(height: 7),
        TextFormField(key: const Key('login_username'), controller: username, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), hintText: '请输入登录账号'), validator: (v) => v == null || v.trim().isEmpty ? '请填写账号' : null),
        const SizedBox(height: 15), const Text('登录密码', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w800)), const SizedBox(height: 7),
        TextFormField(key: const Key('login_password'), controller: password, obscureText: obscure, autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _login(),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline_rounded), hintText: '请输入密码', suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          validator: (v) => v == null || v.isEmpty ? '请填写密码' : null),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgotPassword, child: const Text('忘记密码？'))),
        const SizedBox(height: 5), FilledButton(key: const Key('login_button'), onPressed: busy ? null : _login,
          child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登 录')),
      ]))),
      if (pandoraDemo) ...[const SizedBox(height: 17), Material(color: Palette.pastel, borderRadius: BorderRadius.circular(18), child: ExpansionTile(
        leading: const Icon(Icons.science_rounded, color: Palette.primary), title: const Text('演示账号', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.deep)),
        subtitle: const Text('本机演示 · 无需后端', style: TextStyle(fontSize: 11)), childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 12), children: [
          Wrap(spacing: 6, runSpacing: 5, children: [for (final u in MockRepository.users) ActionChip(label: Text('${u.name} · ${u.roleLabel}', style: const TextStyle(fontSize: 11)), onPressed: () {username.text = u.username; password.text = MockRepository.demoPassword; setState(() {});})]),
        ],
      ))],
      const SizedBox(height: 19), const Center(child: Text('安全登录 · 分级授权 · 每日记录', style: TextStyle(color: Palette.muted, fontSize: 11))),
    ])),
  ))));
}
