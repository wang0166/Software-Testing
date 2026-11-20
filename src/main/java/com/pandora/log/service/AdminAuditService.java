package com.pandora.log.service;

import java.time.*;
import java.time.format.DateTimeParseException;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.AuditChangeDto;
import com.pandora.log.dto.AdminDtos.AuditDetailDto;
import com.pandora.log.dto.AdminDtos.AuditDto;

@Service
public class AdminAuditService {
    private static final Set<String> OBJECT_TYPES = Set.of("LOG", "TASK");
    private static final String TABLES = " FROM operation_audits a LEFT JOIN users u ON u.id=a.operator_id";
    private static final String ACTOR = "coalesce(u.real_name || '（' || u.username || '）', u.real_name, u.username, '未知用户')";

    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    private final ObjectMapper json;

    public AdminAuditService(JdbcTemplate jdbc, AdminSupport support, ObjectMapper json) {
        this.jdbc = jdbc; this.support = support; this.json = json;
    }

    public PageResult<AuditDto> list(String actor, String action, String objectType, String from, String to,
            Integer page, Integer size) {
        support.require("audit:read");
        PageQuery pq = PageQuery.of(page, size);
        String type = normalizeObjectType(objectType);
        StringBuilder where = new StringBuilder(" WHERE 1=1"); List<Object> args = new ArrayList<>();
        if (type != null) { where.append(" AND a.object_type=?"); args.add(type); }
        if (actor != null && !actor.isBlank()) {
            where.append(" AND (position(lower(?) in lower(u.username))>0 OR position(lower(?) in lower(u.real_name))>0)");
            args.add(actor.trim()); args.add(actor.trim());
        }
        if (action != null && !action.isBlank()) { where.append(" AND a.action=?"); args.add(action.trim()); }
        OffsetDateTime start = parse(from, false), end = parse(to, true);
        if (start != null && end != null && end.isBefore(start)) AdminSupport.invalid("审计截止时间不得早于开始时间");
        if (start != null) { where.append(" AND a.created_at>=?"); args.add(start); }
        if (end != null) { where.append(to.length() == 10 ? " AND a.created_at<?" : " AND a.created_at<=?"); args.add(end); }
        Long total = jdbc.queryForObject("SELECT count(*)" + TABLES + where, Long.class, args.toArray());
        args.add(pq.size()); args.add(pq.offset());
        return new PageResult<>(total, pq.page(), pq.size(), jdbc.query(
                "SELECT a.id," + ACTOR + " AS actor,a.action,a.object_type,a.object_id,a.detail,a.created_at,a.result"
                        + TABLES + where + " ORDER BY a.created_at DESC,a.id DESC LIMIT ? OFFSET ?",
                (rs, n) -> {
                    String objectTypeValue = rs.getString("object_type");
                    String objectId = rs.getString("object_id");
                    Detail detail = parseDetail(rs.getString("detail"));
                    return new AuditDto(rs.getLong("id"), rs.getString("actor"), rs.getString("action"),
                            target(objectTypeValue, objectId), toOffset(rs.getObject("created_at", OffsetDateTime.class)),
                            rs.getString("result"), objectTypeValue, objectId, detail.source(), detail.summary());
                }, args.toArray()));
    }

    public AuditDetailDto get(Long id) {
        support.require("audit:read");
        List<AuditDetailDto> rows = jdbc.query(
                "SELECT a.id," + ACTOR + " AS actor,a.action,a.object_type,a.object_id,a.detail,a.created_at,a.result"
                        + TABLES + " WHERE a.id=?",
                (rs, n) -> {
                    String objectTypeValue = rs.getString("object_type");
                    String objectId = rs.getString("object_id");
                    Detail detail = parseDetail(rs.getString("detail"));
                    return new AuditDetailDto(rs.getLong("id"), rs.getString("actor"), rs.getString("action"),
                            target(objectTypeValue, objectId), toOffset(rs.getObject("created_at", OffsetDateTime.class)),
                            rs.getString("result"), objectTypeValue, objectId, detail.source(), detail.summary(),
                            detail.changes());
                }, id);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }
        return rows.get(0);
    }

    private static String normalizeObjectType(String value) {
        if (value == null || value.isBlank()) return null;
        String type = value.trim().toUpperCase();
        if (!OBJECT_TYPES.contains(type)) AdminSupport.invalid("objectType 仅支持 LOG 或 TASK");
        return type;
    }

    private static String target(String objectType, String objectId) {
        if (objectType == null) return "未记录";
        String label = switch (objectType) {
            case "LOG" -> "工作日志";
            case "TASK" -> "派发任务";
            default -> objectType;
        };
        return objectId == null ? label : label + " #" + objectId;
    }

    private Detail parseDetail(String raw) {
        if (raw == null || raw.isBlank()) return new Detail(null, null, List.of());
        try {
            JsonNode root = json.readTree(raw);
            if (!root.isObject()) return new Detail(null, null, List.of());
            List<AuditChangeDto> changes = new ArrayList<>();
            JsonNode nodes = root.get("changes");
            if (nodes != null && nodes.isArray()) {
                for (JsonNode node : nodes) {
                    changes.add(new AuditChangeDto(text(node, "field"), text(node, "before"), text(node, "after")));
                }
            }
            return new Detail(text(root, "source"), text(root, "summary"), changes);
        } catch (Exception ignored) {
            // 历史记录可能是纯文本，缺少结构化字段时按“未记录”展示。
            return new Detail(null, null, List.of());
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value == null || value.isNull() ? null : value.asText();
    }

    private static OffsetDateTime toOffset(OffsetDateTime value) {
        return value == null ? null : value.withOffsetSameInstant(ZoneOffset.ofHours(8));
    }

    private static OffsetDateTime parse(String value, boolean end) {
        if (value == null || value.isBlank()) return null;
        try {
            if (value.length() == 10) return LocalDate.parse(value).plusDays(end ? 1 : 0).atStartOfDay().atOffset(ZoneOffset.ofHours(8));
            return OffsetDateTime.parse(value);
        } catch (DateTimeParseException e) { AdminSupport.invalid("审计时间必须为 ISO-8601 日期或时间戳"); return null; }
    }

    private record Detail(String source, String summary, List<AuditChangeDto> changes) { }
}
