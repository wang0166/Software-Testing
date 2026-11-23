package com.pandora.log.service;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.AdminDtos.ConfigItemDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class ConfigService {

    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final AuditService auditService;

    public ConfigService(JdbcTemplate jdbcTemplate,
            CurrentUserContext currentUserContext,
            AuditService auditService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.auditService = auditService;
    }

    public List<ConfigItemDto> list() {
        requireManage();
        return jdbcTemplate.query("SELECT key, value FROM system_configs ORDER BY key",
                (rs, index) -> new ConfigItemDto(rs.getString("key"), rs.getString("value")));
    }

    public ConfigItemDto update(String key, String value) {
        CurrentUser currentUser = requireManage();
        if (key == null || key.isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "配置项不能为空");
        }
        String cleanKey = key.trim();
        Long exists = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_configs WHERE key = ?",
                Long.class, cleanKey);
        if (exists == null || exists == 0) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "配置项不存在");
        }
        String cleanValue = normalizeValue(cleanKey, value);
        jdbcTemplate.update("UPDATE system_configs SET value = ?, updated_by = ?, updated_at = now() WHERE key = ?",
                cleanValue, currentUser.id(), cleanKey);
        auditService.record("修改配置", "CONFIG", cleanKey, cleanKey + "=" + cleanValue, "SUCCESS");
        return new ConfigItemDto(cleanKey, cleanValue);
    }

    private static String normalizeValue(String key, String value) {
        String cleanValue = value == null ? "" : value.trim();
        if (cleanValue.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "配置值不能为空");
        }
        if (SystemConfigService.LOG_DEADLINE.equals(key)) {
            try {
                return LocalTime.parse(cleanValue, TIME_FORMAT).format(TIME_FORMAT);
            } catch (DateTimeParseException exception) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED, "截止时间格式应为 HH:mm");
            }
        }
        try {
            int number = Integer.parseInt(cleanValue);
            if (number <= 0) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED, "配置值必须为正整数");
            }
        } catch (NumberFormatException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "配置值必须为正整数");
        }
        return cleanValue;
    }

    private CurrentUser requireManage() {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("config:manage")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        return currentUser;
    }
}
