package com.pandora.log.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class PasswordServiceTest {

    private final PasswordService passwordService = new PasswordService(new BCryptPasswordEncoder());

    @Test
    void encodesPasswordWithBcryptAndMatchesIt() {
        String hash = passwordService.encode("secret-123");

        assertThat(hash).isNotEqualTo("secret-123");
        assertThat(hash).startsWith("$2");
        assertThat(passwordService.matches("secret-123", hash)).isTrue();
    }

    @Test
    void rejectsWrongPassword() {
        String hash = passwordService.encode("secret-123");

        assertThat(passwordService.matches("secret-124", hash)).isFalse();
    }

    @Test
    void rejectsMissingHash() {
        assertThat(passwordService.matches("secret-123", null)).isFalse();
    }

    @Test
    void producesDifferentHashesForSamePassword() {
        assertThat(passwordService.encode("secret-123")).isNotEqualTo(passwordService.encode("secret-123"));
    }
}
