package com.pandora.log.service;

import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.entity.RefreshToken;
import com.pandora.log.mapper.RefreshTokenMapper;
import com.pandora.log.security.TokenHashService;

@Service
public class RefreshTokenService {

    private static final String INVALID_REFRESH_TOKEN_MESSAGE = "刷新令牌无效或过期";

    private final RefreshTokenMapper refreshTokenMapper;
    private final SystemConfigService systemConfigService;

    public RefreshTokenService(RefreshTokenMapper refreshTokenMapper, SystemConfigService systemConfigService) {
        this.refreshTokenMapper = refreshTokenMapper;
        this.systemConfigService = systemConfigService;
    }

    public String issue(Long userId) {
        String rawToken = TokenHashService.generateRawToken();
        RefreshToken token = new RefreshToken();
        token.setUserId(userId);
        token.setTokenHash(TokenHashService.sha256(rawToken));
        token.setExpiresAt(OffsetDateTime.now().plusDays(systemConfigService.refreshTokenTtlDays()));
        refreshTokenMapper.insert(token);
        return rawToken;
    }

    public RefreshToken requireUsable(String rawToken) {
        RefreshToken token = refreshTokenMapper.findByTokenHash(TokenHashService.sha256(rawToken));
        if (token == null || !token.isUsableAt(OffsetDateTime.now())) {
            throw new BusinessException(ErrorCode.INVALID_TOKEN, INVALID_REFRESH_TOKEN_MESSAGE);
        }
        return token;
    }

    public String rotate(RefreshToken currentToken) {
        refreshTokenMapper.revokeById(currentToken.getId(), OffsetDateTime.now());
        return issue(currentToken.getUserId());
    }

    public void revoke(String rawToken) {
        refreshTokenMapper.revokeByTokenHash(TokenHashService.sha256(rawToken));
    }
}
