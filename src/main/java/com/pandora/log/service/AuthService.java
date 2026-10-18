package com.pandora.log.service;

import java.time.Duration;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.LoginRequest;
import com.pandora.log.dto.LoginResponse;
import com.pandora.log.dto.TokenResponse;
import com.pandora.log.dto.UserSummary;
import com.pandora.log.entity.RefreshToken;
import com.pandora.log.entity.User;
import com.pandora.log.mapper.UserMapper;
import com.pandora.log.security.JwtService;
import com.pandora.log.security.PasswordService;

@Service
public class AuthService {

    private static final String TOKEN_TYPE = "Bearer";
    private static final String INVALID_REFRESH_TOKEN_MESSAGE = "刷新令牌无效或过期";

    private final UserMapper userMapper;
    private final PasswordService passwordService;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final LoginAttemptPolicy loginAttemptPolicy;
    private final SystemConfigService systemConfigService;

    public AuthService(UserMapper userMapper,
            PasswordService passwordService,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            LoginAttemptPolicy loginAttemptPolicy,
            SystemConfigService systemConfigService) {
        this.userMapper = userMapper;
        this.passwordService = passwordService;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.loginAttemptPolicy = loginAttemptPolicy;
        this.systemConfigService = systemConfigService;
    }

    public LoginResponse login(LoginRequest request) {
        User user = userMapper.findByUsername(request.username().trim());
        if (user == null) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }
        if (user.isDisabled()) {
            throw new BusinessException(ErrorCode.ACCOUNT_DISABLED);
        }

        OffsetDateTime now = OffsetDateTime.now();
        if (user.isLockedAt(now)) {
            throw new BusinessException(ErrorCode.ACCOUNT_LOCKED);
        }
        if (user.getLockedUntil() != null) {
            userMapper.clearLoginFailures(user.getId());
            user.setFailedAttempts(0);
            user.setLockedUntil(null);
        }

        if (!passwordService.matches(request.password(), user.getPasswordHash())) {
            LoginAttemptPolicy.LoginFailureOutcome outcome =
                    loginAttemptPolicy.onFailure(user.getFailedAttempts(), now);
            userMapper.updateLoginFailure(user.getId(), outcome.failedAttempts(), outcome.lockedUntil());
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }

        if (user.getFailedAttempts() > 0) {
            userMapper.clearLoginFailures(user.getId());
        }

        TokenResponse tokens = issueTokens(user);
        return new LoginResponse(
                tokens.accessToken(),
                tokens.refreshToken(),
                tokens.tokenType(),
                tokens.expiresIn(),
                UserSummary.from(user));
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshToken storedToken = refreshTokenService.requireUsable(rawRefreshToken);
        User user = userMapper.findById(storedToken.getUserId());
        if (user == null) {
            throw new BusinessException(ErrorCode.INVALID_TOKEN, INVALID_REFRESH_TOKEN_MESSAGE);
        }
        if (user.isDisabled()) {
            throw new BusinessException(ErrorCode.ACCOUNT_DISABLED);
        }
        if (user.isLockedAt(OffsetDateTime.now())) {
            throw new BusinessException(ErrorCode.ACCOUNT_LOCKED);
        }

        String newRefreshToken = refreshTokenService.rotate(storedToken);
        long ttlMinutes = systemConfigService.accessTokenTtlMinutes();
        String accessToken = jwtService.createAccessToken(user, Duration.ofMinutes(ttlMinutes));
        return new TokenResponse(accessToken, newRefreshToken, TOKEN_TYPE, ttlMinutes * 60);
    }

    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }

    private TokenResponse issueTokens(User user) {
        long ttlMinutes = systemConfigService.accessTokenTtlMinutes();
        String accessToken = jwtService.createAccessToken(user, Duration.ofMinutes(ttlMinutes));
        String refreshToken = refreshTokenService.issue(user.getId());
        return new TokenResponse(accessToken, refreshToken, TOKEN_TYPE, ttlMinutes * 60);
    }
}
