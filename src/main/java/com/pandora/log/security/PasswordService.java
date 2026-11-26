package com.pandora.log.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class PasswordService {

    private static final String BCRYPT_SHA256_PREFIX = "{bcrypt-sha256}";

    private final PasswordEncoder passwordEncoder;

    public PasswordService(PasswordEncoder passwordEncoder) {
        this.passwordEncoder = passwordEncoder;
    }

    public String encode(String rawPassword) {
        return BCRYPT_SHA256_PREFIX + passwordEncoder.encode(prehash(rawPassword));
    }

    public boolean matches(String rawPassword, String passwordHash) {
        if (passwordHash == null) return false;
        if (passwordHash.startsWith(BCRYPT_SHA256_PREFIX)) {
            return passwordEncoder.matches(prehash(rawPassword), passwordHash.substring(BCRYPT_SHA256_PREFIX.length()));
        }
        // 兼容数据库中既有的标准 BCrypt 哈希；用户下次改密后自动采用支持长密码的格式。
        return passwordEncoder.matches(rawPassword, passwordHash);
    }

    private static String prehash(String rawPassword) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(rawPassword.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().withoutPadding().encodeToString(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }
}
