/// Local feedback, not a substitute for the server's password policy or
/// compromised-password checks. Never trim or otherwise transform passwords.
class PasswordPolicy {
  static const minLength = 12;
  static const maxLength = 128;
  final String value;
  const PasswordPolicy(this.value);

  int get length => value.runes.length;
  bool get validLength => length >= minLength && length <= maxLength;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(value);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(value);
  bool get hasDigit => RegExp(r'[0-9]').hasMatch(value);
  bool get hasSymbol => value.runes.any((c) =>
      (c >= 33 && c <= 47) || (c >= 58 && c <= 64) ||
      (c >= 91 && c <= 96) || (c >= 123 && c <= 126));
  bool get hasNoControl => !value.runes.any((c) => c < 32 || (c >= 127 && c <= 159));
  bool get avoidsCommonPatterns {
    final lower = value.toLowerCase();
    return !const ['password', 'qwerty', '123456', 'demo123456']
        .any((pattern) => lower.contains(pattern));
  }
  bool get isStrong => validLength && hasUpper && hasLower && hasDigit &&
      hasSymbol && hasNoControl && avoidsCommonPatterns;

  int get score => [validLength, hasUpper, hasLower, hasDigit, hasSymbol]
      .where((passed) => passed).length;
  String get label {
    if (value.isEmpty) return '未输入';
    if (isStrong) return '强（符合规则）';
    if (!hasNoControl || !avoidsCommonPatterns || length < 8 || score <= 2) {
      return '弱';
    }
    return '中（未达要求）';
  }
  String? get error {
    if (!validLength) return '新密码须为 12–128 个字符';
    if (!hasNoControl) return '密码不能包含控制字符';
    if (!hasUpper || !hasLower || !hasDigit || !hasSymbol) {
      return '须包含大写字母、小写字母、数字和英文特殊符号';
    }
    if (!avoidsCommonPatterns) return '请避免常见弱密码片段';
    return null;
  }
}
