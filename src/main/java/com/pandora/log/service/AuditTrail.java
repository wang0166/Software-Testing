package com.pandora.log.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.AdminDtos.AuditChangeDto;
import com.pandora.log.security.CurrentUserContext;

/**
 * 日志与任务业务审计：与业务事务共用同一连接写入，失败则整体回滚，保证成功操作必有记录且不重复。
 */
@Component
public class AuditTrail {

    public static final String USER = "USER";
    public static final String SYSTEM = "SYSTEM";

    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;
    private final ObjectMapper json;

    public AuditTrail(JdbcTemplate jdbc, CurrentUserContext context, ObjectMapper json) {
        this.jdbc = jdbc;
        this.context = context;
        this.json = json;
    }

    public void success(String action, String objectType, Object objectId, String source,
            String summary, List<AuditChangeDto> changes) {
        CurrentUser operator = context.require();
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("source", source);
        detail.put("summary", summary);
        if (changes != null && !changes.isEmpty()) {
            detail.put("changes", changes);
        }
        jdbc.update("INSERT INTO operation_audits(operator_id, action, object_type, object_id, detail, result) "
                + "VALUES (?, ?, ?, ?, ?, 'SUCCESS')",
                operator.id(), action, objectType, objectId == null ? null : String.valueOf(objectId),
                serialize(detail));
    }

    private String serialize(Map<String, Object> detail) {
        try {
            return json.writeValueAsString(detail);
        } catch (JsonProcessingException exception) {
            throw new BusinessException(ErrorCode.INTERNAL_ERROR);
        }
    }
}
