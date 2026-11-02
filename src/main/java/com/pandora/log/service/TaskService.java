package com.pandora.log.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.AssigneeDto;
import com.pandora.log.dto.MobileDtos.AssignmentDetailDto;
import com.pandora.log.dto.MobileDtos.AssignmentDto;
import com.pandora.log.dto.MobileDtos.AssignmentStateDto;
import com.pandora.log.dto.MobileDtos.DispatchRequest;
import com.pandora.log.dto.MobileDtos.DispatchResultDto;
import com.pandora.log.dto.MobileDtos.DispatchedTaskDto;
import com.pandora.log.dto.MobileDtos.RecipientDto;
import com.pandora.log.dto.MobileDtos.ReceivedTaskDto;
import com.pandora.log.dto.MobileDtos.ReviewHistoryDto;
import com.pandora.log.dto.MobileDtos.TaskDetailDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class TaskService {

    private static final Set<String> URGENCIES = Set.of("URGENT", "NOT_URGENT");
    private static final Set<String> EXECUTION_STATUSES = Set.of("NOT_STARTED", "IN_PROGRESS", "COMPLETED");

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public TaskService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public List<RecipientDto> recipients() {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        String sql = switch (currentUser.roleCode()) {
            case "FOUNDER" -> "SELECT u.id, u.username, u.real_name, u.role_code, u.department_id, u.team_id "
                    + "FROM users u WHERE u.role_code = 'DEPT_MANAGER' AND u.status = 'ACTIVE' ORDER BY u.id";
            case "DEPT_MANAGER" -> "SELECT u.id, u.username, u.real_name, u.role_code, u.department_id, u.team_id "
                    + "FROM users u WHERE u.role_code = 'TEAM_LEADER' AND u.status = 'ACTIVE' "
                    + "AND u.department_id = ? ORDER BY u.id";
            case "TEAM_LEADER" -> "SELECT u.id, u.username, u.real_name, u.role_code, u.department_id, u.team_id "
                    + "FROM users u WHERE u.role_code = 'EMPLOYEE' AND u.status = 'ACTIVE' "
                    + "AND u.team_id = ? ORDER BY u.id";
            default -> throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        };
        Object[] args = "FOUNDER".equals(currentUser.roleCode())
                ? new Object[0]
                : new Object[] { "DEPT_MANAGER".equals(currentUser.roleCode())
                        ? currentUser.departmentId()
                        : currentUser.teamId() };
        return jdbcTemplate.query(sql, (rs, index) -> new RecipientDto(
                rs.getLong("id"),
                rs.getString("username"),
                rs.getString("real_name"),
                rs.getString("role_code"),
                rs.getObject("department_id") == null ? null : rs.getLong("department_id"),
                rs.getObject("team_id") == null ? null : rs.getLong("team_id"),
                List.of()), args);
    }

    @Transactional
    public DispatchResultDto dispatch(DispatchRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);

        String name = trim(request.name());
        if (name.isEmpty() || name.length() > 200) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String details = trim(request.details());
        if (details.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        LocalDateTime startDate = parseTaskDate(request.startDate(), false);
        LocalDateTime deadline = parseTaskDate(request.deadline(), true);
        if (!deadline.isAfter(startDate)) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String urgency = trim(request.urgency()).toUpperCase();
        if (!URGENCIES.contains(urgency)) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }

        List<Long> assigneeIds = request.assigneeIds();
        if (assigneeIds == null || assigneeIds.isEmpty()
                || assigneeIds.stream().anyMatch(id -> id == null || id <= 0)) {
            throw new BusinessException(ErrorCode.INVALID_ASSIGNEES);
        }
        if (new HashSet<>(assigneeIds).size() != assigneeIds.size()) {
            throw new BusinessException(ErrorCode.INVALID_ASSIGNEES);
        }

        Set<Long> allowed = allowedRecipientIds(currentUser);
        if (!allowed.containsAll(assigneeIds)) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }

        Long taskId = jdbcTemplate.queryForObject(
                "INSERT INTO tasks (sender_id, name, details, start_date, deadline, urgency) "
                        + "VALUES (?, ?, ?, ?, ?, ?) RETURNING id",
                Long.class, currentUser.id(), name, details, startDate, deadline, urgency);
        for (Long assigneeId : assigneeIds) {
            jdbcTemplate.update(
                    "INSERT INTO task_assignments (task_id, assignee_id) VALUES (?, ?)",
                    taskId, assigneeId);
        }
        return new DispatchResultDto(taskId, assigneeIds.size());
    }

    public PageResult<DispatchedTaskDto> dispatched(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        PageQuery pageQuery = PageQuery.of(page, size);

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM tasks WHERE sender_id = ?", Long.class, currentUser.id());

        List<DispatchedTaskDto> items = jdbcTemplate.query(
                "SELECT t.id, t.name, t.details, t.start_date, t.deadline, t.urgency, t.created_at, "
                        + "COUNT(a.id) AS assignee_count, "
                        + "COUNT(a.id) FILTER (WHERE a.execution_status = 'COMPLETED') AS completed_count, "
                        + "COUNT(a.id) FILTER (WHERE a.review_status = 'PENDING') AS pending_review_count "
                        + "FROM tasks t LEFT JOIN task_assignments a ON a.task_id = t.id "
                        + "WHERE t.sender_id = ? GROUP BY t.id "
                        + "ORDER BY t.created_at DESC, t.id DESC LIMIT ? OFFSET ?",
                (rs, index) -> new DispatchedTaskDto(
                        rs.getLong("id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getInt("assignee_count"),
                        rs.getInt("completed_count"),
                        rs.getInt("pending_review_count"),
                        rs.getObject("created_at", OffsetDateTime.class)),
                currentUser.id(), pageQuery.size(), pageQuery.offset());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public TaskDetailDto detail(Long taskId) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:dispatch")) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        List<TaskDetailDto> tasks = jdbcTemplate.query(
                "SELECT id, sender_id, name, details, start_date, deadline, urgency, created_at, updated_at "
                        + "FROM tasks WHERE id = ?",
                (rs, index) -> new TaskDetailDto(
                        rs.getLong("id"),
                        rs.getLong("sender_id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getObject("created_at", OffsetDateTime.class),
                        rs.getObject("updated_at", OffsetDateTime.class),
                        List.of()),
                taskId);
        if (tasks.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        TaskDetailDto task = tasks.get(0);
        if (!task.senderId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }

        List<AssignmentDto> assignments = jdbcTemplate.query(
                "SELECT a.id, a.assignee_id, u.real_name, a.execution_status, a.review_status, a.updated_at "
                        + "FROM task_assignments a JOIN users u ON u.id = a.assignee_id "
                        + "WHERE a.task_id = ? ORDER BY a.id",
                (rs, index) -> new AssignmentDto(
                        rs.getLong("id"),
                        new AssigneeDto(rs.getLong("assignee_id"), rs.getString("real_name")),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        rs.getObject("updated_at", OffsetDateTime.class)),
                taskId);

        return new TaskDetailDto(task.id(), task.senderId(), task.name(), task.details(),
                task.startDate(), task.deadline(), task.urgency(), task.createdAt(), task.updatedAt(),
                assignments);
    }

    public PageResult<ReceivedTaskDto> received(String status, String reviewStatus, Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        requireExecutePermission(currentUser);
        PageQuery pageQuery = PageQuery.of(page, size);

        StringBuilder where = new StringBuilder(" WHERE a.assignee_id = ?");
        List<Object> args = new ArrayList<>();
        args.add(currentUser.id());
        if (status != null && !status.isBlank()) {
            String value = status.trim().toUpperCase();
            if (!EXECUTION_STATUSES.contains(value)) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            where.append(" AND a.execution_status = ?");
            args.add(value);
        }
        if (reviewStatus != null && !reviewStatus.isBlank()) {
            String value = reviewStatus.trim().toUpperCase();
            if (!Set.of("NONE", "PENDING", "APPROVED", "RETURNED").contains(value)) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED);
            }
            where.append(" AND a.review_status = ?");
            args.add(value);
        }

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM task_assignments a" + where, Long.class, args.toArray());

        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<ReceivedTaskDto> items = jdbcTemplate.query(
                "SELECT a.id AS assignment_id, t.id AS task_id, t.name, t.details, t.start_date, t.deadline, "
                        + "t.urgency, a.execution_status, a.review_status, s.id AS sender_id, "
                        + "s.real_name AS sender_name, a.updated_at "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "JOIN users s ON s.id = t.sender_id" + where
                        + " ORDER BY a.updated_at DESC, a.id DESC LIMIT ? OFFSET ?",
                (rs, index) -> new ReceivedTaskDto(
                        rs.getLong("assignment_id"),
                        rs.getLong("task_id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        new AssigneeDto(rs.getLong("sender_id"), rs.getString("sender_name")),
                        rs.getObject("updated_at", OffsetDateTime.class)),
                pageArgs.toArray());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    @Transactional
    public AssignmentStateDto progress(Long assignmentId, String status) {
        CurrentUser currentUser = currentUserContext.require();
        requireExecutePermission(currentUser);
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.NOT_ASSIGNEE);
        }
        String target = status == null ? "" : status.trim().toUpperCase();
        if (!EXECUTION_STATUSES.contains(target)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (target.equals(row.executionStatus())) {
            return state(row);
        }
        if ("PENDING".equals(row.reviewStatus()) || "APPROVED".equals(row.reviewStatus())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        boolean allowed = ("NOT_STARTED".equals(row.executionStatus()) && "IN_PROGRESS".equals(target))
                || ("IN_PROGRESS".equals(row.executionStatus()) && "COMPLETED".equals(target));
        if (!allowed) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }

        int updated = jdbcTemplate.update(
                "UPDATE task_assignments SET execution_status = ?, updated_at = now() "
                        + "WHERE id = ? AND execution_status = ? AND review_status IN ('NONE', 'RETURNED')",
                target, assignmentId, row.executionStatus());
        if (updated == 0) {
            AssignmentRow latest = requireAssignment(assignmentId);
            if (target.equals(latest.executionStatus())) {
                return state(latest);
            }
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        return state(requireAssignment(assignmentId));
    }

    @Transactional
    public AssignmentStateDto inviteReview(Long assignmentId) {
        CurrentUser currentUser = currentUserContext.require();
        requireExecutePermission(currentUser);
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.NOT_ASSIGNEE);
        }
        if (!"COMPLETED".equals(row.executionStatus())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        if ("PENDING".equals(row.reviewStatus())) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_PENDING);
        }
        if ("APPROVED".equals(row.reviewStatus())) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_HANDLED);
        }

        int updated = jdbcTemplate.update(
                "UPDATE task_assignments SET review_status = 'PENDING', updated_at = now() "
                        + "WHERE id = ? AND review_status = ?",
                assignmentId, row.reviewStatus());
        if (updated == 0) {
            AssignmentRow latest = requireAssignment(assignmentId);
            if ("PENDING".equals(latest.reviewStatus())) {
                throw new BusinessException(ErrorCode.REVIEW_ALREADY_PENDING);
            }
            if ("APPROVED".equals(latest.reviewStatus())) {
                throw new BusinessException(ErrorCode.REVIEW_ALREADY_HANDLED);
            }
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        jdbcTemplate.update(
                "INSERT INTO task_reviews (assignment_id, action, actor_id, comment) VALUES (?, 'INVITED', ?, NULL)",
                assignmentId, currentUser.id());
        return state(requireAssignment(assignmentId));
    }

    @Transactional
    public AssignmentStateDto review(Long assignmentId, String result, String comment) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:dispatch")) {
            throw new BusinessException(ErrorCode.NOT_SENDER);
        }
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.senderId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.NOT_SENDER);
        }

        String action = result == null ? "" : result.trim().toUpperCase();
        if (!"APPROVED".equals(action) && !"RETURNED".equals(action)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (!"PENDING".equals(row.reviewStatus())) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_HANDLED);
        }

        String sql = "RETURNED".equals(action)
                ? "UPDATE task_assignments SET review_status = 'RETURNED', execution_status = 'IN_PROGRESS', "
                        + "updated_at = now() WHERE id = ? AND review_status = 'PENDING'"
                : "UPDATE task_assignments SET review_status = 'APPROVED', updated_at = now() "
                        + "WHERE id = ? AND review_status = 'PENDING'";
        int updated = jdbcTemplate.update(sql, assignmentId);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_HANDLED);
        }
        jdbcTemplate.update(
                "INSERT INTO task_reviews (assignment_id, action, actor_id, comment) VALUES (?, ?, ?, ?)",
                assignmentId, action, currentUser.id(), trim(comment).isEmpty() ? null : comment.trim());
        return state(requireAssignment(assignmentId));
    }

    public List<ReviewHistoryDto> reviews(Long assignmentId) {
        CurrentUser currentUser = currentUserContext.require();
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id()) && !row.senderId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        return jdbcTemplate.query(
                "SELECT action, actor_id, comment, created_at FROM task_reviews "
                        + "WHERE assignment_id = ? ORDER BY created_at ASC, id ASC",
                (rs, index) -> new ReviewHistoryDto(
                        rs.getString("action"),
                        rs.getLong("actor_id"),
                        rs.getString("comment"),
                        rs.getObject("created_at", OffsetDateTime.class)),
                assignmentId);
    }

    public AssignmentDetailDto assignmentDetail(Long assignmentId) {
        CurrentUser currentUser = currentUserContext.require();
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        List<AssignmentDetailDto> rows = jdbcTemplate.query(
                "SELECT a.id AS assignment_id, t.id AS task_id, t.name, t.details, t.start_date, t.deadline, "
                        + "t.urgency, a.execution_status, a.review_status, s.id AS sender_id, "
                        + "s.real_name AS sender_name "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "JOIN users s ON s.id = t.sender_id WHERE a.id = ?",
                (rs, index) -> new AssignmentDetailDto(
                        rs.getLong("assignment_id"),
                        rs.getLong("task_id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        new AssigneeDto(rs.getLong("sender_id"), rs.getString("sender_name")),
                        List.of()),
                assignmentId);
        AssignmentDetailDto detail = rows.get(0);
        return new AssignmentDetailDto(detail.assignmentId(), detail.taskId(), detail.name(), detail.details(),
                detail.startDate(), detail.deadline(), detail.urgency(), detail.executionStatus(),
                detail.reviewStatus(), detail.sender(), reviews(assignmentId));
    }

    private AssignmentRow requireAssignment(Long assignmentId) {
        List<AssignmentRow> rows = jdbcTemplate.query(
                "SELECT a.id, a.task_id, a.assignee_id, t.sender_id, a.execution_status, a.review_status "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id WHERE a.id = ?",
                (rs, index) -> new AssignmentRow(
                        rs.getLong("id"),
                        rs.getLong("task_id"),
                        rs.getLong("assignee_id"),
                        rs.getLong("sender_id"),
                        rs.getString("execution_status"),
                        rs.getString("review_status")),
                assignmentId);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        return rows.get(0);
    }

    private AssignmentStateDto state(AssignmentRow row) {
        return new AssignmentStateDto(row.id(), row.executionStatus(), row.reviewStatus(), OffsetDateTime.now());
    }

    private Set<Long> allowedRecipientIds(CurrentUser currentUser) {
        String sql = switch (currentUser.roleCode()) {
            case "FOUNDER" -> "SELECT u.id FROM users u WHERE u.role_code = 'DEPT_MANAGER' AND u.status = 'ACTIVE'";
            case "DEPT_MANAGER" -> "SELECT u.id FROM users u WHERE u.role_code = 'TEAM_LEADER' "
                    + "AND u.status = 'ACTIVE' AND u.department_id = ?";
            case "TEAM_LEADER" -> "SELECT u.id FROM users u WHERE u.role_code = 'EMPLOYEE' "
                    + "AND u.status = 'ACTIVE' AND u.team_id = ?";
            default -> throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        };
        List<Long> ids = "FOUNDER".equals(currentUser.roleCode())
                ? jdbcTemplate.queryForList(sql, Long.class)
                : jdbcTemplate.queryForList(sql, Long.class, "DEPT_MANAGER".equals(currentUser.roleCode())
                        ? currentUser.departmentId()
                        : currentUser.teamId());
        return new HashSet<>(ids);
    }

    private void requireDispatchPermission(CurrentUser currentUser) {
        if (!currentUser.hasPermission("task:dispatch")) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
    }

    private void requireExecutePermission(CurrentUser currentUser) {
        if (!currentUser.hasPermission("task:execute")) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
    }

    private LocalDateTime parseTaskDate(String value, boolean end) {
        try {
            String text = trim(value);
            // 兼容已发布的纯日期请求；新请求严格保存分钟，不截断秒或时区偏移。
            if (text.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")) {
                LocalDate date = LocalDate.parse(text);
                return end ? date.atTime(23, 59) : date.atStartOfDay();
            }
            if (!text.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:00)?")) {
                throw new IllegalArgumentException();
            }
            return LocalDateTime.parse(text);
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
    }

    private static String trim(String value) {
        return value == null ? "" : value.trim();
    }

    private record AssignmentRow(Long id, Long taskId, Long assigneeId, Long senderId,
            String executionStatus, String reviewStatus) {
    }
}
