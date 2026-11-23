package com.pandora.log.service;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.AuditDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class AuditService {

    private static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private static final RowMapper<AuditDto> MAPPER = (rs, index) -> new AuditDto(
            rs.getLong("id"),
            rs.getString("actor"),
            rs.getString("action"),
            rs.getString("target"),
            rs.getObject("created_at", java.time.OffsetDateTime.class),
            rs.getString("result"),
            rs.getString("object_type"),
            rs.getString("object_id"),
            null,
            null);

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public AuditService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    /** 记录一次管理操作；审计写入失败不影响主流程。 */
    public void record(String action, String objectType, String objectId, String detail, String result) {
        CurrentUser currentUser = currentUserContext.get();
        try {
            jdbcTemplate.update(
                    "INSERT INTO operation_audits (operator_id, action, object_type, object_id, detail, result) "
                            + "VALUES (?, ?, ?, ?, ?, ?)",
                    currentUser == null ? null : currentUser.id(),
                    action, objectType, objectId, detail, result);
        } catch (RuntimeException ignored) {
            // 审计失败不阻断业务
        }
    }

    public PageResult<AuditDto> list(String actor, String action, Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("audit:read")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        PageQuery pageQuery = PageQuery.of(page, size);

        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        List<Object> args = new ArrayList<>();
        if (actor != null && !actor.isBlank()) {
            where.append(" AND COALESCE(u.username, '') ILIKE ?");
            args.add("%" + actor.trim() + "%");
        }
        if (action != null && !action.isBlank()) {
            where.append(" AND a.action ILIKE ?");
            args.add("%" + action.trim() + "%");
        }

        String from = " FROM operation_audits a LEFT JOIN users u ON u.id = a.operator_id";
        Long total = jdbcTemplate.queryForObject("SELECT COUNT(*)" + from + where, Long.class, args.toArray());

        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<AuditDto> items = jdbcTemplate.query(
                "SELECT a.id, COALESCE(u.username, 'system') AS actor, a.action, a.result, a.created_at, "
                        + "a.object_type, a.object_id, "
                        + "COALESCE(a.object_type, '-') || COALESCE(' ' || a.object_id, '') AS target"
                        + from + where + " ORDER BY a.created_at DESC, a.id DESC LIMIT ? OFFSET ?",
                MAPPER, pageArgs.toArray());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }
}
