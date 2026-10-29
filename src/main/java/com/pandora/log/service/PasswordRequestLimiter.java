package com.pandora.log.service;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PasswordRequestLimiter {
    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final byte[] secret;
    public PasswordRequestLimiter(JdbcTemplate jdbc, Clock clock, @Value("${app.jwt.secret}") String secret) {
        this.jdbc = jdbc; this.clock = clock; this.secret = secret.getBytes(StandardCharsets.UTF_8);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean allow(String operation, String account, String ip) {
        OffsetDateTime now = OffsetDateTime.now(clock);
        // 两个桶都计数，账号是否存在、最终业务是否成功均不改变限流路径。
        int byAccount = increment(operation + ":account:" + account, now);
        int byIp = increment(operation + ":ip:" + ip, now);
        jdbc.update("DELETE FROM password_request_limits WHERE window_started_at<?", now.minusDays(1));
        return byAccount <= (operation.equals("password-review") ? 20 : 5) && byIp <= 30;
    }

    private int increment(String key, OffsetDateTime now) {
        return jdbc.queryForObject("INSERT INTO password_request_limits(bucket_key,window_started_at,attempts) "
                + "VALUES (?,?,1) ON CONFLICT(bucket_key) DO UPDATE SET attempts=CASE "
                + "WHEN password_request_limits.window_started_at<=? THEN 1 ELSE password_request_limits.attempts+1 END,"
                + "window_started_at=CASE WHEN password_request_limits.window_started_at<=? THEN ? "
                + "ELSE password_request_limits.window_started_at END RETURNING attempts", Integer.class,
                digest(key), now, now.minusMinutes(15), now.minusMinutes(15), now);
    }
    private String digest(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) { throw new IllegalStateException("限流摘要初始化失败", e); }
    }
}
