package com.pandora.log.service;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.RecipientDto;
import com.pandora.log.dto.TaskHandoverDtos.ConfirmHandoverRequest;
import com.pandora.log.dto.TaskHandoverDtos.HandoverDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class TaskHandoverService {
    private static final String HANDOVER_SELECT =
            "SELECT h.id,h.original_user_id,h.original_assignment_id,old.real_name AS original_user_name," +
            "t.id AS task_id,t.name AS task_name,t.details AS task_details,a.execution_status,h.status," +
            "t.task_type,t.urgency,COALESCE(latest.note,'') AS progress_note," +
            "COALESCE(latest.progress_percent,CASE WHEN a.execution_status='COMPLETED' THEN 100 ELSE 0 END) AS progress_percent," +
            "COALESCE(h.deadline,t.deadline) AS deadline,h.completed_at,h.note,h.new_assignee_id," +
            "fresh.real_name AS new_assignee_name,h.new_assignment_id " +
            "FROM task_handovers h JOIN task_assignments a ON a.id=h.original_assignment_id " +
            "JOIN tasks t ON t.id=a.task_id JOIN users old ON old.id=h.original_user_id " +
            "LEFT JOIN users fresh ON fresh.id=h.new_assignee_id " +
            "LEFT JOIN LATERAL (SELECT p.progress_percent,p.note FROM task_progress_updates p " +
            "WHERE p.assignment_id=a.id ORDER BY p.created_at DESC,p.id DESC LIMIT 1) latest ON true ";

    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;
    private final AuditTrail audit;

    public TaskHandoverService(JdbcTemplate jdbc, CurrentUserContext context, AuditTrail audit) {
        this.jdbc = jdbc;
        this.context = context;
        this.audit = audit;
    }

    @Transactional
    public void generateForDisabledUser(Long userId) {
        jdbc.update("INSERT INTO task_handovers(original_user_id,original_assignment_id) " +
                "SELECT assignee_id,id FROM task_assignments WHERE assignee_id=? AND execution_status<>'COMPLETED' " +
                "ON CONFLICT(original_assignment_id) DO NOTHING", userId);
    }

    public PageResult<HandoverDto> handovers(Integer page, Integer size) {
        CurrentUser user = context.require();
        PageQuery pq = PageQuery.of(page, size);
        Scope scope = supervisorScope(user, "old");
        if (scope == null) return new PageResult<>(0, pq.page(), pq.size(), List.of());
        Long total = jdbc.queryForObject(
                "SELECT COUNT(*) FROM task_handovers h JOIN users old ON old.id=h.original_user_id WHERE " +
                        scope.sql(), Long.class, scope.args());
        List<Object> args = new ArrayList<>(Arrays.asList(scope.args()));
        args.add(pq.size());
        args.add(pq.offset());
        List<HandoverDto> rows = jdbc.query(HANDOVER_SELECT + "WHERE " + scope.sql() +
                " ORDER BY CASE h.status WHEN 'PENDING' THEN 0 ELSE 1 END,h.created_at DESC " +
                "LIMIT ? OFFSET ?", this::map, args.toArray());
        return new PageResult<>(total == null ? 0 : total, pq.page(), pq.size(), rows);
    }

    public PageResult<RecipientDto> candidates(Long handoverId, Integer page, Integer size) {
        CurrentUser user = context.require();
        HandoverRow row = requireVisible(handoverId, user, false);
        PageQuery pq = PageQuery.of(page, size);
        CandidateScope scope = candidateScope(user, row);
        String where = " WHERE u.status='ACTIVE' AND u.id<>? AND " + scope.sql() +
                " AND NOT EXISTS(SELECT 1 FROM task_assignments x WHERE x.task_id=? AND x.assignee_id=u.id)";
        List<Object> base = new ArrayList<>();
        base.add(row.originalUserId());
        base.addAll(Arrays.asList(scope.args()));
        base.add(row.taskId());
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM users u" + where,
                Long.class, base.toArray());
        base.add(pq.size());
        base.add(pq.offset());
        List<RecipientDto> items = jdbc.query(
                "SELECT u.id,u.username,u.real_name,u.role_code,u.department_id,u.team_id FROM users u" +
                        where + " ORDER BY u.id LIMIT ? OFFSET ?",
                (rs, i) -> new RecipientDto(rs.getLong("id"), rs.getString("username"),
                        rs.getString("real_name"), rs.getString("role_code"),
                        nullableLong(rs, "department_id"), nullableLong(rs, "team_id"), List.of()),
                base.toArray());
        return new PageResult<>(total == null ? 0 : total, pq.page(), pq.size(), items);
    }

    @Transactional
    public HandoverDto confirm(Long handoverId, ConfirmHandoverRequest request) {
        CurrentUser user = context.require();
        if (request == null || request.newAssigneeId() == null || request.note() == null ||
                request.note().isBlank() || request.note().trim().length() > 1000) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        HandoverRow row = requireVisible(handoverId, user, true);
        if (!"PENDING".equals(row.status())) {
            throw new BusinessException(ErrorCode.HANDOVER_ALREADY_COMPLETED);
        }
        CandidateScope scope = candidateScope(user, row);
        List<Object> args = new ArrayList<>();
        args.add(request.newAssigneeId());
        args.add(row.originalUserId());
        args.addAll(Arrays.asList(scope.args()));
        args.add(row.taskId());
        Boolean eligible = jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM users u WHERE u.id=? AND u.status='ACTIVE' AND u.id<>? AND " +
                        scope.sql() + " AND NOT EXISTS(SELECT 1 FROM task_assignments x " +
                        "WHERE x.task_id=? AND x.assignee_id=u.id))",
                Boolean.class, args.toArray());
        if (!Boolean.TRUE.equals(eligible)) {
            throw new BusinessException(ErrorCode.HANDOVER_ASSIGNEE_CONFLICT);
        }
        Long assignmentId;
        try {
            assignmentId = jdbc.queryForObject(
                    "INSERT INTO task_assignments(task_id,assignee_id,execution_status,review_status) " +
                            "VALUES (?,?,?,'NONE') RETURNING id",
                    Long.class, row.taskId(), request.newAssigneeId(), row.executionStatus());
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.HANDOVER_ASSIGNEE_CONFLICT);
        }
        int progress = row.progressPercent();
        String progressNote = "任务交接：" + request.note().trim();
        if (row.progressNote() != null && !row.progressNote().isBlank()) {
            progressNote += "；原进度说明：" + row.progressNote();
        }
        jdbc.update("INSERT INTO task_progress_updates(assignment_id,author_id,execution_status,progress_percent,note) " +
                "VALUES (?,?,?,?,?)", assignmentId, user.id(), row.executionStatus(), progress, progressNote);
        int changed = jdbc.update("UPDATE task_handovers SET status='COMPLETED',new_assignee_id=?," +
                "new_assignment_id=?,note=?,deadline=?,completed_by=?,completed_at=now() " +
                "WHERE id=? AND status='PENDING'", request.newAssigneeId(), assignmentId,
                request.note().trim(), request.deadline(), user.id(), handoverId);
        if (changed != 1) throw new BusinessException(ErrorCode.HANDOVER_ALREADY_COMPLETED);
        audit.success("确认任务交接", "TASK_HANDOVER", handoverId, AuditTrail.USER,
                "任务已交接给新的在职负责人", List.of());
        return requireDto(handoverId, user);
    }

    private HandoverRow requireVisible(Long id, CurrentUser user, boolean lock) {
        Scope scope = supervisorScope(user, "old");
        if (scope == null) throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        List<Object> args = new ArrayList<>();
        args.add(id);
        args.addAll(Arrays.asList(scope.args()));
        String suffix = lock ? " FOR UPDATE OF h" : "";
        List<HandoverRow> rows = jdbc.query(
                "SELECT h.id,h.original_user_id,h.original_assignment_id,h.status,t.id AS task_id," +
                        "a.execution_status,COALESCE(latest.progress_percent," +
                        "CASE WHEN a.execution_status='COMPLETED' THEN 100 ELSE 0 END) AS progress_percent," +
                        "COALESCE(latest.note,'') AS progress_note,old.department_id,old.team_id " +
                        "FROM task_handovers h JOIN task_assignments a ON a.id=h.original_assignment_id " +
                        "JOIN tasks t ON t.id=a.task_id JOIN users old ON old.id=h.original_user_id " +
                        "LEFT JOIN LATERAL (SELECT p.progress_percent,p.note FROM task_progress_updates p " +
                        "WHERE p.assignment_id=a.id ORDER BY p.created_at DESC,p.id DESC LIMIT 1) latest ON true " +
                        "WHERE h.id=? AND " + scope.sql() + suffix,
                (rs, i) -> new HandoverRow(rs.getLong("id"), rs.getLong("original_user_id"),
                        rs.getLong("original_assignment_id"), rs.getString("status"), rs.getLong("task_id"),
                        rs.getString("execution_status"), rs.getInt("progress_percent"),
                        rs.getString("progress_note"), nullableLong(rs, "department_id"),
                        nullableLong(rs, "team_id")), args.toArray());
        if (rows.isEmpty()) throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        return rows.get(0);
    }

    private HandoverDto requireDto(Long id, CurrentUser user) {
        Scope scope = supervisorScope(user, "old");
        List<Object> args = new ArrayList<>();
        args.add(id);
        args.addAll(Arrays.asList(scope.args()));
        return jdbc.query(HANDOVER_SELECT + "WHERE h.id=? AND " + scope.sql(), this::map, args.toArray())
                .stream().findFirst().orElseThrow(() -> new BusinessException(ErrorCode.TASK_ACCESS_DENIED));
    }

    private HandoverDto map(java.sql.ResultSet rs, int index) throws java.sql.SQLException {
        return new HandoverDto(String.valueOf(rs.getLong("id")), rs.getLong("original_user_id"),
                rs.getLong("original_assignment_id"), rs.getString("original_user_name"),
                rs.getString("task_name"), rs.getString("task_details"), rs.getString("execution_status"),
                rs.getString("status"), rs.getString("task_type"), rs.getString("urgency"),
                rs.getString("progress_note"), rs.getInt("progress_percent"),
                rs.getObject("deadline", LocalDateTime.class),
                rs.getObject("completed_at", OffsetDateTime.class), rs.getString("note"),
                rs.getString("new_assignee_name"), nullableLong(rs, "new_assignee_id"),
                nullableLong(rs, "new_assignment_id"));
    }

    private Scope supervisorScope(CurrentUser user, String alias) {
        return switch (user.roleCode()) {
            case "FOUNDER" -> new Scope(alias + ".role_code<>'FOUNDER' AND " + alias + ".role_code<>'ADMIN'",
                    new Object[0]);
            case "DEPT_MANAGER" -> new Scope(alias + ".department_id=? AND " +
                    alias + ".role_code IN ('TEAM_LEADER','EMPLOYEE')", new Object[] {user.departmentId()});
            case "TEAM_LEADER" -> new Scope(alias + ".team_id=? AND " + alias + ".role_code='EMPLOYEE'",
                    new Object[] {user.teamId()});
            default -> null;
        };
    }

    private CandidateScope candidateScope(CurrentUser user, HandoverRow handover) {
        return switch (user.roleCode()) {
            case "FOUNDER" -> new CandidateScope("u.role_code IN ('DEPT_MANAGER','TEAM_LEADER','EMPLOYEE')",
                    new Object[0]);
            case "DEPT_MANAGER" -> new CandidateScope(
                    "u.department_id=? AND u.role_code IN ('TEAM_LEADER','EMPLOYEE')",
                    new Object[] {handover.departmentId()});
            case "TEAM_LEADER" -> new CandidateScope("u.team_id=? AND u.role_code='EMPLOYEE'",
                    new Object[] {handover.teamId()});
            default -> throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        };
    }

    private static Long nullableLong(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        return rs.getObject(column) == null ? null : rs.getLong(column);
    }

    private record Scope(String sql, Object[] args) {
    }
    private record CandidateScope(String sql, Object[] args) {
    }
    private record HandoverRow(Long id, Long originalUserId, Long originalAssignmentId, String status,
            Long taskId, String executionStatus, int progressPercent, String progressNote,
            Long departmentId, Long teamId) {
    }
}
