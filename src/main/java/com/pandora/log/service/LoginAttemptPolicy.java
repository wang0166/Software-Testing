package com.pandora.log.service;

import java.time.OffsetDateTime;

import org.springframework.stereotype.Component;

@Component
public class LoginAttemptPolicy {

    private final SystemConfigService systemConfigService;

    public LoginAttemptPolicy(SystemConfigService systemConfigService) {
        this.systemConfigService = systemConfigService;
    }

    public LoginFailureOutcome onFailure(int currentFailedAttempts, OffsetDateTime now) {
        int maxFailures = Math.max(1, systemConfigService.loginMaxFailures());
        int nextAttempts = currentFailedAttempts + 1;
        if (nextAttempts >= maxFailures) {
            int lockMinutes = Math.max(1, systemConfigService.loginLockMinutes());
            return new LoginFailureOutcome(0, now.plusMinutes(lockMinutes));
        }
        return new LoginFailureOutcome(nextAttempts, null);
    }

    public record LoginFailureOutcome(int failedAttempts, OffsetDateTime lockedUntil) {
    }
}
