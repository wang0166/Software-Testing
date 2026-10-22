package com.pandora.log.service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.LogCommentDto;
import com.pandora.log.dto.MobileDtos.WorkLogDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class LogService {

    private static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");

    private static final String LOG_SELECT = "SELECT l.id, l.author_id, u.real_name AS author_name, l.log_date, "
            + "l.content, l.status, l.is_important, l.submitted_at, l.created_at, l.updated_at "
            + "FROM work_logs l JOIN users u ON u.id = l.author_id ";

    private static final RowMapper<WorkLogDto> LOG_MAPPER = (rs, index) -> new WorkLogDto(
            rs.getLong("id"),
            rs.getLong("author_id"),
            rs.getString("author_name"),
            rs.getObject("log_date", LocalDate.class),
            rs.getString("content"),
            rs.getString("status"),
            rs.getBoolean("is_important"),
            rs.getObject("submitted_at", OffsetDateTime.class),
            rs.getObject("created_at", OffsetDateTime.class),
            rs.getObject("updated_at", OffsetDateTime.class));

    private static final RowMapper<LogCommentDto> COMMENT_MAPPER = (rs, index) -> new LogCommentDto(
            rs.getLong("id"),
            rs.getLong("log_id"),
            rs.getLong("commenter_id"),
            rs.getString("author_name"),
            rs.getString("content"),
            rs.getObject("created_at", OffsetDateTime.class),
            rs.getObject("parent_id") == null ? null : rs.getLong("parent_id"));

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final SystemConfigService systemConfigService;

    public LogService(JdbcTemplate jdbcTemplate,
            CurrentUserContext currentUserContext,
            SystemConfigService systemConfigService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.systemConfigService = systemConfigService;
    }

    public PageResult<WorkLogDto> list(String date, String status, Long authorId, Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        PageQuery pageQuery = PageQuery.of(page, size);

        Scope scope = logScope(currentUser);
        StringBuilder where = new StringBuilder(" WHERE ").append(scope.condition());
        List<Object> args = new ArrayList<>(scope.arguments());

        if (date != null && !date.isBlank()) {
            where.append(" AND l.log_date = ?");
            args.add(parseDate(date));
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND l.status = ?");
            args.add(parseLogStatus(status));
        }
        if (authorId != null) {
            where.append(" AND l.author_id = ?");
            args.add(authorId);
        }

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM work_logs l JOIN users u ON u.id = l.author_id" + where,
                Long.class, args.toArray());

        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<WorkLogDto> items = jdbcTemplate.query(
                LOG_SELECT + where + " ORDER BY l.log_date DESC, l.id DESC LIMIT ? OFFSET ?",
                LOG_MAPPER, pageArgs.toArray());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public WorkLogDto get(Long id) {
        CurrentUser currentUser = currentUserContext.require();
        WorkLogDto log = findLog(id);
        if (log == null) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        }
        assertVisible(currentUser, log.authorId());
        return log;
    }

    @Transactional
    public WorkLogDto create(String content) {
        CurrentUser currentUser = currentUserContext.require();
        requireWritePermission(currentUser);
        ensureBeforeDeadline();
        String text = requireContent(content);

        LocalDate today = LocalDate.now(ZONE);
        try {
            Long id = jdbcTemplate.queryForObject(
                    "INSERT INTO work_logs (author_id, log_date, content, status) "
                            + "VALUES (?, ?, ?, 'DRAFT') RETURNING id",
                    Long.class, currentUser.id(), today, text);
            return findLog(id);
        } catch (DuplicateKeyException exception) {
            throw new BusinessException(ErrorCode.LOG_ALREADY_EXISTS);
        }
    }

    @Transactional
    public WorkLogDto update(Long id, String content) {
        CurrentUser currentUser = currentUserContext.require();
        requireWritePermission(currentUser);
        WorkLogDto existing = requireOwnLog(id, currentUser);
        if ("SUBMITTED".equals(existing.status())) {
            throw new BusinessException(ErrorCode.LOG_ALREADY_SUBMITTED);
        }
        ensureBeforeDeadline();
        String text = requireContent(content);

        int updated = jdbcTemplate.update(
                "UPDATE work_logs SET content = ?, updated_at = now() WHERE id = ? AND status = 'DRAFT'",
                text, id);
        if (updated == 0) {
            WorkLogDto latest = findLog(id);
            if (latest != null && "SUBMITTED".equals(latest.status())) {
                throw new BusinessException(ErrorCode.LOG_ALREADY_SUBMITTED);
            }
            throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        }
        return findLog(id);
    }

    @Transactional
    public WorkLogDto submit(Long id) {
        CurrentUser currentUser = currentUserContext.require();
        requireWritePermission(currentUser);
        WorkLogDto existing = requireOwnLog(id, currentUser);
        if ("SUBMITTED".equals(existing.status())) {
            return existing;
        }
        ensureBeforeDeadline();

        int updated = jdbcTemplate.update(
                "UPDATE work_logs SET status = 'SUBMITTED', submitted_at = now(), updated_at = now() "
                        + "WHERE id = ? AND status = 'DRAFT'",
                id);
        if (updated == 0) {
            WorkLogDto latest = findLog(id);
            if (latest != null && "SUBMITTED".equals(latest.status())) {
                return latest;
            }
            throw new BusinessException(ErrorCode.LOG_ALREADY_SUBMITTED);
        }
        return findLog(id);
    }

    public List<LogCommentDto> comments(Long logId) {
        CurrentUser currentUser = currentUserContext.require();
        WorkLogDto log = requireLog(logId);
        if (!canParticipate(currentUser, log.authorId())) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        return jdbcTemplate.query(
                "SELECT c.id, c.log_id, c.commenter_id, u.real_name AS author_name, c.content, "
                        + "c.created_at, c.parent_id FROM log_comments c "
                        + "JOIN users u ON u.id = c.commenter_id "
                        + "WHERE c.log_id = ? ORDER BY c.created_at ASC, c.id ASC",
                COMMENT_MAPPER, logId);
    }

    @Transactional
    public LogCommentDto addComment(Long logId, String content, Long parentId) {
        CurrentUser currentUser = currentUserContext.require();
        WorkLogDto log = requireLog(logId);
        if (!canParticipate(currentUser, log.authorId())) {
            throw new BusinessException(ErrorCode.NOT_DIRECT_SUPERIOR);
        }
        String text = (content == null ? "" : content.trim());
        if (text.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (parentId != null) {
            List<Long> parentLogIds = jdbcTemplate.queryForList(
                    "SELECT log_id FROM log_comments WHERE id = ?", Long.class, parentId);
            if (parentLogIds.isEmpty() || !parentLogIds.get(0).equals(logId)) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
        }

        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO log_comments (log_id, commenter_id, parent_id, content) "
                        + "VALUES (?, ?, ?, ?) RETURNING id",
                Long.class, logId, currentUser.id(), parentId, text);
        return jdbcTemplate.queryForObject(
                "SELECT c.id, c.log_id, c.commenter_id, u.real_name AS author_name, c.content, "
                        + "c.created_at, c.parent_id FROM log_comments c "
                        + "JOIN users u ON u.id = c.commenter_id WHERE c.id = ?",
                COMMENT_MAPPER, id);
    }

    private WorkLogDto requireOwnLog(Long id, CurrentUser currentUser) {
        WorkLogDto log = requireLog(id);
        if (!log.authorId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        return log;
    }

    private WorkLogDto requireLog(Long id) {
        WorkLogDto log = findLog(id);
        if (log == null) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        }
        return log;
    }

    private WorkLogDto findLog(Long id) {
        List<WorkLogDto> rows = jdbcTemplate.query(LOG_SELECT + " WHERE l.id = ?", LOG_MAPPER, id);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private void assertVisible(CurrentUser currentUser, Long authorId) {
        Scope scope = logScope(currentUser);
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users u WHERE u.id = ? AND " + scope.condition(),
                Long.class, prepend(authorId, scope.arguments()).toArray());
        if (count == null || count == 0) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private boolean canParticipate(CurrentUser currentUser, Long authorId) {
        if (currentUser.id().equals(authorId)) {
            return true;
        }
        return isDirectSuperior(currentUser.id(), authorId);
    }

    private boolean isDirectSuperior(Long supervisorId, Long authorId) {
        List<String> roles = jdbcTemplate.queryForList(
                "SELECT role_code FROM users WHERE id = ?", String.class, authorId);
        if (roles.isEmpty()) {
            return false;
        }
        String role = roles.get(0);
        String sql;
        switch (role) {
            case "EMPLOYEE" -> sql = "SELECT t.leader_id FROM teams t JOIN users a ON a.team_id = t.id WHERE a.id = ?";
            case "TEAM_LEADER" -> sql = "SELECT d.manager_id FROM departments d "
                    + "JOIN users a ON a.department_id = d.id WHERE a.id = ?";
            case "DEPT_MANAGER" -> sql = "SELECT c.founder_id FROM companies c "
                    + "JOIN departments d ON d.company_id = c.id "
                    + "JOIN users a ON a.department_id = d.id WHERE a.id = ?";
            default -> {
                return false;
            }
        }
        List<Long> ids = jdbcTemplate.queryForList(sql, Long.class, authorId);
        return !ids.isEmpty() && ids.get(0) != null && ids.get(0).equals(supervisorId);
    }

    private void requireWritePermission(CurrentUser currentUser) {
        if (!currentUser.hasPermission("log:write")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private void ensureBeforeDeadline() {
        LocalTime deadline = systemConfigService.logDeadline();
        LocalTime now = LocalTime.now(ZONE);
        if (!now.isBefore(deadline)) {
            throw new BusinessException(ErrorCode.LOG_DEADLINE_PASSED);
        }
    }

    private String requireContent(String content) {
        String text = content == null ? "" : content.trim();
        if (text.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return text;
    }

    private LocalDate parseDate(String value) {
        try {
            return LocalDate.parse(value.trim());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private String parseLogStatus(String value) {
        String status = value.trim().toUpperCase();
        if (!"DRAFT".equals(status) && !"SUBMITTED".equals(status)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        return status;
    }

    private static Scope logScope(CurrentUser currentUser) {
        String role = currentUser.roleCode();
        if ("EMPLOYEE".equals(role)) {
            return new Scope("u.id = ?", List.of(currentUser.id()));
        }
        if ("TEAM_LEADER".equals(role)) {
            return currentUser.teamId() == null
                    ? new Scope("1 = 0", List.of())
                    : new Scope("u.team_id = ?", List.of(currentUser.teamId()));
        }
        if ("DEPT_MANAGER".equals(role)) {
            return currentUser.departmentId() == null
                    ? new Scope("1 = 0", List.of())
                    : new Scope("u.department_id = ?", List.of(currentUser.departmentId()));
        }
        return new Scope("1 = 1", List.of());
    }

    private static List<Object> prepend(Object first, List<Object> rest) {
        List<Object> args = new ArrayList<>();
        args.add(first);
        args.addAll(rest);
        return args;
    }

    private record Scope(String condition, List<Object> arguments) {
    }
}
