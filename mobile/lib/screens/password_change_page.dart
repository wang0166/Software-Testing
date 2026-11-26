import 'package:flutter/material.dart';
import '../core/password_policy.dart';
import '../core/theme.dart';
import '../data/repository.dart';

/// Passwords stay in the form's memory only. The repository performs the
/// change; a successful local strength check is not a successful API call.
class PasswordChangePage extends StatefulWidget {
  final PandoraRepository repo;
  final bool demo;
  const PasswordChangePage({super.key, required this.repo, this.demo = false});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideOld = true, _hideNext = true, _hideConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  PasswordPolicy get _policy => PasswordPolicy(_next.text);
  bool get _canSubmit => !_busy && _old.text.isNotEmpty &&
      _policy.isStrong && _next.text != _old.text && _next.text == _confirm.text;

  void _onEdit(String _) => setState(() => _error = null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repo.changePassword(
        currentPassword: _old.text, newPassword: _next.text,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '修改未确认成功，请检查原密码、登录状态和网络后重试。';
        });
      }
      return;
    }
    if (!mounted) return;
    // Clear sensitive fields before leaving the route.
    _old.clear();
    _next.clear();
    _confirm.clear();
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  Widget _field({required String id, required String label,
    required TextEditingController controller, required bool hidden,
    required VoidCallback toggle, required String hint,
    TextInputAction action = TextInputAction.next}) => TextField(
      key: Key(id), controller: controller, enabled: !_busy,
      obscureText: hidden, autocorrect: false, enableSuggestions: false,
      autofillHints: [hint], textInputAction: action,
      onChanged: _onEdit,
      onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
      decoration: InputDecoration(labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hidden ? '显示密码' : '隐藏密码',
          onPressed: _busy ? null : toggle,
          icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        )),
    );

  Widget _rule(String label, bool passed) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(passed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 17, color: passed ? Palette.darkGreen : Palette.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 12,
        color: passed ? Palette.darkGreen : Palette.muted))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    final color = policy.isStrong ? Palette.darkGreen :
      policy.label == '弱' ? Palette.coral : Palette.gold;
    final segments = _next.text.isEmpty ? 0 : policy.isStrong ? 3 :
        policy.label == '弱' ? 1 : 2;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('修改密码'),
          automaticallyImplyLeading: !_busy),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('设置新的登录密码', style: TextStyle(
            color: Palette.deep, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('验证原密码后即可自行修改，无需提交管理员审核。',
            style: TextStyle(color: Palette.muted, height: 1.5)),
          if (widget.demo) ...[
            const SizedBox(height: 12),
            const Text('演示模式：仅本次 App 运行有效，重启后恢复初始演示密码。请勿输入真实密码。',
              style: TextStyle(color: Palette.deep, fontSize: 12, height: 1.5)),
          ],
          const SizedBox(height: 20),
          _field(id: 'password_current', label: '原密码', controller: _old,
            hidden: _hideOld, toggle: () => setState(() => _hideOld = !_hideOld),
            hint: AutofillHints.password),
          const SizedBox(height: 14),
          _field(id: 'password_new', label: '新密码', controller: _next,
            hidden: _hideNext, toggle: () => setState(() => _hideNext = !_hideNext),
            hint: AutofillHints.newPassword),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
            color: Palette.mutedBlue, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('密码强度：${policy.label}', key: const Key('password_strength'),
                style: TextStyle(color: _next.text.isEmpty ? Palette.muted : color,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [for (var i = 0; i < 3; i++) Expanded(child: Container(
                margin: EdgeInsets.only(right: i == 2 ? 0 : 4), height: 6,
                decoration: BoxDecoration(color: i < segments ? color : Palette.divider,
                  borderRadius: BorderRadius.circular(6)),
              ))]),
              const SizedBox(height: 8),
              _rule('12–128 个字符', policy.validLength),
              _rule('包含大写字母和小写字母', policy.hasUpper && policy.hasLower),
              _rule('包含数字', policy.hasDigit),
              _rule('包含英文特殊符号', policy.hasSymbol),
              _rule('避免常见弱密码片段和控制字符',
                _next.text.isNotEmpty && policy.avoidsCommonPatterns && policy.hasNoControl),
            ])),
          const SizedBox(height: 14),
          _field(id: 'password_confirm', label: '确认新密码', controller: _confirm,
            hidden: _hideConfirm, toggle: () => setState(() => _hideConfirm = !_hideConfirm),
            hint: AutofillHints.newPassword, action: TextInputAction.done),
          if (_next.text.isNotEmpty && _next.text == _old.text)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('新密码不能与原密码相同',
              style: TextStyle(color: Palette.coral))),
          if (_confirm.text.isNotEmpty && _confirm.text != _next.text)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('两次输入的新密码不一致',
              style: TextStyle(color: Palette.coral))),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!,
              style: const TextStyle(color: Palette.coral, height: 1.5))),
          const SizedBox(height: 20),
          FilledButton(key: const Key('password_submit'),
            onPressed: _canSubmit ? _submit : null,
            child: _busy ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Text('确认修改')),
          const SizedBox(height: 12),
          const Text('建议使用独一无二的长密码，并避免在其他网站重复使用。',
            style: TextStyle(fontSize: 12, color: Palette.muted, height: 1.5)),
        ])),
      ),
    );
  }
}
