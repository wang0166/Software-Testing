package com.pandora.log.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;

import org.junit.jupiter.api.Test;

import com.pandora.log.entity.User;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;

class JwtServiceTest {

    private static final String SECRET = "pandora-log-test-secret-key-0123456789";
    private static final String ISSUER = "pandora-log-test";

    private final JwtService jwtService = new JwtService(SECRET, ISSUER);

    private User user() {
        User user = new User();
        user.setId(42L);
        user.setUsername("zhangsan");
        user.setRoleCode("EMPLOYEE");
        return user;
    }

    @Test
    void createsAndParsesAccessToken() {
        String token = jwtService.createAccessToken(user(), Duration.ofMinutes(30));

        Claims claims = jwtService.parseAccessToken(token);

        assertThat(jwtService.extractUserId(claims)).isEqualTo(42L);
        assertThat(claims.get("username", String.class)).isEqualTo("zhangsan");
        assertThat(claims.get("role", String.class)).isEqualTo("EMPLOYEE");
        assertThat(claims.getIssuer()).isEqualTo(ISSUER);
        assertThat(claims.getExpiration()).isAfter(claims.getIssuedAt());
    }

    @Test
    void rejectsExpiredToken() {
        String token = jwtService.createAccessToken(user(), Duration.ofSeconds(-10));

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOf(ExpiredJwtException.class);
    }

    @Test
    void rejectsTokenSignedWithAnotherSecret() {
        JwtService another = new JwtService("another-secret-key-0123456789-abcdefgh", ISSUER);
        String token = another.createAccessToken(user(), Duration.ofMinutes(5));

        assertThatThrownBy(() -> jwtService.parseAccessToken(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void rejectsMalformedToken() {
        assertThatThrownBy(() -> jwtService.parseAccessToken("not-a-token"))
                .isInstanceOf(JwtException.class);
    }
}
