package com.pandora.log.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

class LoginAttemptPolicyTest {

    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-10-18T10:00:00+08:00");

    private LoginAttemptPolicy policy(int maxFailures, int lockMinutes) {
        SystemConfigService configService = mock(SystemConfigService.class);
        when(configService.loginMaxFailures()).thenReturn(maxFailures);
        when(configService.loginLockMinutes()).thenReturn(lockMinutes);
        return new LoginAttemptPolicy(configService);
    }

    @Test
    void incrementsCounterBelowThreshold() {
        LoginAttemptPolicy.LoginFailureOutcome outcome = policy(5, 15).onFailure(2, NOW);

        assertThat(outcome.failedAttempts()).isEqualTo(3);
        assertThat(outcome.lockedUntil()).isNull();
    }

    @Test
    void locksWhenThresholdIsReached() {
        LoginAttemptPolicy.LoginFailureOutcome outcome = policy(5, 15).onFailure(4, NOW);

        assertThat(outcome.failedAttempts()).isZero();
        assertThat(outcome.lockedUntil()).isEqualTo(NOW.plusMinutes(15));
    }

    @Test
    void usesConfiguredThresholdAndDuration() {
        LoginAttemptPolicy.LoginFailureOutcome outcome = policy(3, 5).onFailure(2, NOW);

        assertThat(outcome.lockedUntil()).isEqualTo(NOW.plusMinutes(5));
    }
}
