import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/mock_repository.dart';
import '../widgets/redesign.dart';
import '../widgets/ui.dart';

class LoginPage extends StatefulWidget {
  final AppState app;
  const LoginPage({super.key, required this.app});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _obscure = true, _busy = false;
  @override void dispose() { _user.dispose(); _pass.dispose(); super.dispose(); }
  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try { await widget.app.login(_user.text.trim(), _pass.text); }
    catch (e) { if (mounted) toast(context, '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.auto_stories_rounded, size: 22, color: Colors.white)),
        const SizedBox(width: 10),
        const Text('PANDORA  ·  潘多拉', style: TextStyle(fontWeight: FontWeight.w900, color: Palette.deep, letterSpacing: .4, fontSize: 18)),
        const Spacer(), const Text('WORK  01', style: TextStyle(fontSize: 10, color: Palette.muted, letterSpacing: 1.5, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 22),
      _masthead(),
      const SizedBox(height: 18),
      StoryCard(padding: const EdgeInsets.all(22), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Expanded(child: Text('欢迎回来', style: TextStyle(fontWeight: FontWeight.w900, color: Palette.deep, fontSize: 24))), ColoredIcon(icon: Icons.waving_hand_rounded, background: Palette.pastel, color: Color(0xFFBC853E), size: 40)]),
        const SizedBox(height: 3), const Text('登录你的工作空间', style: TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 18),
        const Text('登录账号', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.deep, fontSize: 12)),
        const SizedBox(height: 7),
        TextFormField(key: const Key('login_username'), controller: _user, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: '请输入用户名', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (s) => s == null || s.trim().isEmpty ? '请填写账号' : null),
        const SizedBox(height: 14),
        const Text('登录密码', style: TextStyle(fontWeight: FontWeight.w800, color: Palette.deep, fontSize: 12)),
        const SizedBox(height: 7),
        TextFormField(key: const Key('login_password'), controller: _pass, obscureText: _obscure, autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _login(), decoration: InputDecoration(hintText: '请输入密码', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: _obscure ? '显示密码' : '隐藏密码', onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined))), validator: (s) => s == null || s.isEmpty ? '请填写密码' : null),
        const SizedBox(height: 18),
        FilledButton(key: const Key('login_button'), onPressed: _busy ? null : _login, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('进入工作空间'), SizedBox(width: 9), Icon(Icons.arrow_forward_rounded, size: 18)])),
        const SizedBox(height: 10),
        const Center(child: Text('如需重置密码，请联系系统管理员', style: TextStyle(color: Palette.muted, fontSize: 10))),
      ]))),
      if (pandoraDemo) ...[
        const SizedBox(height: 16),
        StoryCard(color: Palette.pastel, padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.science_outlined, size: 19, color: Color(0xFFB27C38)), SizedBox(width: 7), Text('体验模式', style: TextStyle(color: Palette.deep, fontSize: 15, fontWeight: FontWeight.w900)), Spacer(), Text('NO SERVER', style: TextStyle(color: Color(0xFFB27C38), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))]),
          const SizedBox(height: 5), const Text('选择一个角色自动填入演示账号', style: TextStyle(color: Palette.muted, fontSize: 11)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final u in MockRepository.users) ActionChip(
            avatar: const Icon(Icons.person_outline_rounded, color: Palette.primary, size: 15),
            backgroundColor: Colors.white, side: BorderSide.none,
            label: Text('${u.name} · ${u.roleLabel}', style: const TextStyle(fontSize: 11, color: Palette.deep, fontWeight: FontWeight.w800)),
            onPressed: () { _user.text = u.username; _pass.text = MockRepository.demoPassword; setState(() {}); },
          )]),
          const SizedBox(height: 8), const Text('仅演示模式：demo123456', style: TextStyle(color: Palette.muted, fontSize: 10)),
        ])),
      ],
      const SizedBox(height: 22),
      const Center(child: Text('RECORD  ·  CONNECT  ·  GROW', style: TextStyle(color: Palette.muted, letterSpacing: 2, fontWeight: FontWeight.w700, fontSize: 9))),
    ]))),
  ))));
  Widget _masthead() => Container(
    height: 186, clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.fromLTRB(23, 19, 23, 18),
    decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(28)),
    child: Stack(children: [
      Positioned(right: -66, top: -70, child: Container(width: 225, height: 225, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF368E86), width: 40)))),
      Positioned(right: -1, bottom: -48, child: Icon(Icons.auto_stories_rounded, color: Colors.white.withValues(alpha: .14), size: 137)),
      Positioned.fill(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ONE DAY, ONE STORY', style: TextStyle(color: Palette.gold, letterSpacing: 2.1, fontWeight: FontWeight.w900, fontSize: 10)),
        const Spacer(),
        const Text('把每一天，\n写成成长的篇章。', style: TextStyle(color: Colors.white, fontSize: 26, height: 1.3, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text('日志 · 任务 · 协作 · 洞察', style: TextStyle(color: Colors.white.withValues(alpha: .74), fontSize: 12)),
      ])),
    ]),
  );
}
