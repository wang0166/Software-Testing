package com.pandora.log.service;

import java.time.*;
import java.time.format.DateTimeParseException;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.AuditDto;

@Service
public class AdminAuditService {
    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    public AdminAuditService(JdbcTemplate jdbc, AdminSupport support) { this.jdbc = jdbc; this.support = support; }

    public PageResult<AuditDto> list(String actor, String action, String from, String to, Integer page, Integer size) {
        support.require("audit:read");
        PageQuery pq = PageQuery.of(page, size);
        StringBuilder where = new StringBuilder(" WHERE 1=1"); List<Object> args = new ArrayList<>();
        if (actor != null && !actor.isBlank()) {
            where.append(" AND (position(lower(?) in lower(u.username))>0 OR position(lower(?) in lower(u.real_name))>0)");
            args.add(actor.trim()); args.add(actor.trim());
        }
        if (action != null && !action.isBlank()) { where.append(" AND position(? in a.action)>0"); args.add(action.trim()); }
        OffsetDateTime start = parse(from, false), end = parse(to, true);
        if (start != null && end != null && end.isBefore(start)) AdminSupport.invalid("审计截止时间不得早于开始时间");
        if (start != null) { where.append(" AND a.created_at>=?"); args.add(start); }
        if (end != null) { where.append(to.length() == 10 ? " AND a.created_at<?" : " AND a.created_at<=?"); args.add(end); }
        String tables = " FROM operation_audits a LEFT JOIN users u ON u.id=a.operator_id";
        Long total = jdbc.queryForObject("SELECT count(*)" + tables + where, Long.class, args.toArray());
        args.add(pq.size()); args.add(pq.offset());
        return new PageResult<>(total, pq.page(), pq.size(), jdbc.query(
                "SELECT a.id,coalesce(u.real_name,u.username,'未知用户') AS actor,a.action,"
                + "concat(a.object_type,' #',a.object_id) AS target,a.created_at,a.result" + tables + where
                + " ORDER BY a.created_at DESC,a.id DESC LIMIT ? OFFSET ?", (rs, n) -> new AuditDto(rs.getLong("id"),
                        rs.getString("actor"), rs.getString("action"), rs.getString("target"),
                        rs.getObject("created_at", OffsetDateTime.class).withOffsetSameInstant(ZoneOffset.ofHours(8)),
                        rs.getString("result")), args.toArray()));
    }
    private static OffsetDateTime parse(String value, boolean end) {
        if (value == null || value.isBlank()) return null;
        try {
            if (value.length() == 10) return LocalDate.parse(value).plusDays(end ? 1 : 0).atStartOfDay().atOffset(ZoneOffset.ofHours(8));
            return OffsetDateTime.parse(value);
        } catch (DateTimeParseException e) { AdminSupport.invalid("审计时间必须为 ISO-8601 日期或时间戳"); return null; }
    }
}
