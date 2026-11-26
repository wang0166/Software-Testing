package com.pandora.log.security;

import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Component;
import com.pandora.log.common.BusinessException;
import com.pandora.log.common.ErrorCode;

/** 登录密码规则。不会保存、记录或返回任何原始密码。 */
@Component
public class PasswordPolicy {
    private static final Set<String> COMMON = Set.of(
            "123456", "12345678", "123456789", "1234567890", "111111", "000000",
            "password", "password1", "password123", "qwerty", "qwerty123", "abc123",
            "admin", "admin123", "letmein", "welcome", "welcome123", "iloveyou",
            "p@ssword", "p@ssw0rd", "passw0rd", "changeme");

    public void validate(String password) {
        if (password == null) invalid();
        int length = password.codePointCount(0, password.length());
        if (length < 12 || length > 128 || password.codePoints().anyMatch(Character::isWhitespace)
                || password.codePoints().anyMatch(Character::isISOControl)) invalid();
        boolean lower = password.chars().anyMatch(c -> c >= 'a' && c <= 'z');
        boolean upper = password.chars().anyMatch(c -> c >= 'A' && c <= 'Z');
        boolean digit = password.chars().anyMatch(c -> c >= '0' && c <= '9');
        boolean special = password.chars().anyMatch(c -> c >= 0x21 && c <= 0x7e
                && !Character.isLetterOrDigit(c));
        if (!lower || !upper || !digit || !special || isCommon(password)) invalid();
    }

    private static boolean isCommon(String password) {
        String normalized = password.toLowerCase(Locale.ROOT);
        if (COMMON.contains(normalized)) return true;
        String compact = normalized.replaceAll("[^a-z0-9]", "");
        if (COMMON.contains(compact)) return true;
        String simplified = compact
                .replace('0', 'o').replace('1', 'i').replace('3', 'e').replace('4', 'a').replace('5', 's');
        return COMMON.contains(simplified);
    }

    private static void invalid() {
        throw new BusinessException(ErrorCode.VALIDATION_FAILED,
                "新密码须为 12–128 个字符，包含大小写字母、数字和英文特殊符号，且不能使用常见弱密码");
    }
}
