package com.pandora.log.service;

import org.springframework.stereotype.Service;

import com.pandora.log.mapper.SystemConfigMapper;

@Service
public class SystemConfigService {

    public static final String LOGIN_MAX_FAILURES = "login_max_failures";
    public static final String LOGIN_LOCK_MINUTES = "login_lock_minutes";
    public static final String ACCESS_TOKEN_TTL_MINUTES = "access_token_ttl_minutes";
    public static final String REFRESH_TOKEN_TTL_DAYS = "refresh_token_ttl_days";

    private final SystemConfigMapper systemConfigMapper;

    public SystemConfigService(SystemConfigMapper systemConfigMapper) {
        this.systemConfigMapper = systemConfigMapper;
    }

    public int intValue(String key, int fallback) {
        String value = systemConfigMapper.findValue(key);
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException exception) {
            return fallback;
        }
    }

    public int loginMaxFailures() {
        return intValue(LOGIN_MAX_FAILURES, 5);
    }

    public int loginLockMinutes() {
        return intValue(LOGIN_LOCK_MINUTES, 15);
    }

    public long accessTokenTtlMinutes() {
        return intValue(ACCESS_TOKEN_TTL_MINUTES, 120);
    }

    public int refreshTokenTtlDays() {
        return intValue(REFRESH_TOKEN_TTL_DAYS, 7);
    }
}
