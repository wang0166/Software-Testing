package com.pandora.log.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.AuditChangeDto;
import com.pandora.log.dto.MobileDtos.ApprovalRequest;
import com.pandora.log.dto.MobileDtos.AssigneeDto;
import com.pandora.log.dto.MobileDtos.AssignmentDetailDto;
import com.pandora.log.dto.MobileDtos.AssignmentDto;
import com.pandora.log.dto.MobileDtos.AssignmentStateDto;
import com.pandora.log.dto.MobileDtos.ChangeRequestDto;
import com.pandora.log.dto.MobileDtos.ChangeRequestViewDto;
import com.pandora.log.dto.MobileDtos.DispatchRequest;
import com.pandora.log.dto.MobileDtos.DispatchRequestDto;
import com.pandora.log.dto.MobileDtos.DispatchRequestResultDto;
import com.pandora.log.dto.MobileDtos.DispatchRequestViewDto;
import com.pandora.log.dto.MobileDtos.DispatchResultDto;
import com.pandora.log.dto.MobileDtos.DispatchedTaskDto;
import com.pandora.log.dto.MobileDtos.RecipientDto;
import com.pandora.log.dto.MobileDtos.ReceivedTaskDto;
import com.pandora.log.dto.MobileDtos.ReviewHistoryDto;
import com.pandora.log.dto.MobileDtos.SubordinateSummaryDto;
import com.pandora.log.dto.MobileDtos.SubordinateTaskItemDto;
import com.pandora.log.dto.MobileDtos.TaskDetailDto;
import com.pandora.log.dto.MobileDtos.TaskProgressRequest;
import com.pandora.log.dto.MobileDtos.TaskProgressUpdateDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class TaskService {

    private static final Set<String> URGENCIES = Set.of("URGENT", "NOT_URGENT");
    private static final Set<String> EXECUTION_STATUSES = Set.of("NOT_STARTED", "IN_PROGRESS", "COMPLETED");
    private static final Set<String> PROGRESS_STATUSES =
            Set.of("NOT_STARTED", "IN_PROGRESS", "BLOCKED", "COMPLETED");
    private static final Set<String> TASK_TYPES = Set.of("GENERAL", "DEVELOPMENT", "PRODUCT", "TESTING",
            "OPERATION", "SALES", "ADMINISTRATIVE", "OTHER");
    private static final Set<String> REQUEST_STATUSES =
            Set.of("PENDING", "APPROVED", "REJECTED", "WITHDRAWN");

    private static final String RECIPIENT_COLUMNS =
            "u.id, u.username, u.real_name, u.role_code, u.department_id, u.team_id ";
    private static final RowMapper<RecipientDto> RECIPIENT_MAPPER = (rs, index) -> new RecipientDto(
            rs.getLong("id"),
            rs.getString("username"),
            rs.getString("real_name"),
            rs.getString("role_code"),
            rs.getObject("department_id") == null ? null : rs.getLong("department_id"),
            rs.getObject("team_id") == null ? null : rs.getLong("team_id"),
            List.of());

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final AuditTrail auditTrail;

    public TaskService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext, AuditTrail auditTrail) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.auditTrail = auditTrail;
    }

    public List<RecipientDto> recipients() {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        RecipientQuery query = recipientQuery(currentUser);
        return jdbcTemplate.query("SELECT " + RECIPIENT_COLUMNS + "FROM users u WHERE " + query.filter()
                + " ORDER BY u.id", RECIPIENT_MAPPER, query.args());
    }

    public PageResult<RecipientDto> allRecipients(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        PageQuery pageQuery = PageQuery.of(page, size);
        RecipientQuery query = recipientQuery(currentUser);

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users u WHERE " + query.filter(), Long.class, query.args());
        List<Object> pageArgs = new ArrayList<>(Arrays.asList(query.args()));
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<RecipientDto> items = jdbcTemplate.query(
                "SELECT " + RECIPIENT_COLUMNS + "FROM users u WHERE " + query.filter()
                        + " ORDER BY u.id LIMIT ? OFFSET ?",
                RECIPIENT_MAPPER, pageArgs.toArray());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public PageResult<SubordinateSummaryDto> subordinateOverview(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        PageQuery pageQuery = PageQuery.of(page, size);
        SubordinateScope scope = subordinateScope(currentUser);
        if (scope == null) {
            return new PageResult<>(0, pageQuery.page(), pageQuery.size(), List.of());
        }

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users u WHERE " + scope.condition(), Long.class, scope.args());
        List<Object> pageArgs = new ArrayList<>(Arrays.asList(scope.args()));
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<SubordinateRow> rows = jdbcTemplate.query(
                "SELECT u.id, u.username, u.real_name, u.role_code, u.department_id, "
                        + "d.name AS department_name, u.team_id, t.name AS team_name "
                        + "FROM users u LEFT JOIN departments d ON d.id = u.department_id "
                        + "LEFT JOIN teams t ON t.id = u.team_id WHERE " + scope.condition()
                        + " ORDER BY u.id LIMIT ? OFFSET ?",
                (rs, index) -> new SubordinateRow(
                        rs.getLong("id"),
                        rs.getString("username"),
                        rs.getString("real_name"),
                        rs.getString("role_code"),
                        rs.getObject("department_id") == null ? null : rs.getLong("department_id"),
                        rs.getString("department_name"),
                        rs.getObject("team_id") == null ? null : rs.getLong("team_id"),
                        rs.getString("team_name")),
                pageArgs.toArray());
        if (rows.isEmpty()) {
            return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), List.of());
        }

        List<Long> userIds = rows.stream().map(SubordinateRow::userId).toList();
        String placeholders = String.join(",", Collections.nCopies(userIds.size(), "?"));
        List<SubordinateTaskRow> taskRows = jdbcTemplate.query(
                "SELECT a.id AS assignment_id, a.assignee_id, t.id AS task_id, t.name, t.details, "
                        + "t.start_date, t.deadline, t.urgency, t.task_type, a.execution_status, a.review_status, "
                        + "s.id AS sender_id, s.real_name AS sender_name, u.real_name AS assignee_name, a.updated_at, "
                        + "latest.progress_percent, latest.note AS progress_note, "
                        + "latest.created_at AS progress_updated_at, "
                        + "CASE WHEN latest.execution_status = 'BLOCKED' THEN 1 ELSE 0 END AS open_issue_count "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "JOIN users s ON s.id = t.sender_id JOIN users u ON u.id = a.assignee_id "
                        + "LEFT JOIN LATERAL (SELECT pu.execution_status, pu.progress_percent, pu.note, pu.created_at "
                        + "FROM task_progress_updates pu WHERE pu.assignment_id = a.id "
                        + "ORDER BY pu.created_at DESC, pu.id DESC LIMIT 1) latest ON true "
                        + "WHERE a.assignee_id IN (" + placeholders + ") "
                        + "ORDER BY a.updated_at DESC, a.id DESC",
                (rs, index) -> new SubordinateTaskRow(
                        rs.getLong("assignment_id"),
                        rs.getLong("assignee_id"),
                        rs.getLong("task_id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("task_type"),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        rs.getLong("sender_id"),
                        rs.getString("sender_name"),
                        rs.getString("assignee_name"),
                        rs.getObject("updated_at", OffsetDateTime.class),
                        rs.getObject("progress_percent", Integer.class),
                        rs.getString("progress_note"),
                        rs.getObject("progress_updated_at", OffsetDateTime.class),
                        rs.getInt("open_issue_count")),
                userIds.toArray());

        Map<Long, List<SubordinateTaskItemDto>> tasksByUser = taskRows.stream()
                .collect(Collectors.groupingBy(SubordinateTaskRow::assigneeId,
                        Collectors.mapping(SubordinateTaskRow::toItem, Collectors.toList())));
        List<SubordinateSummaryDto> items = rows.stream().map(row -> {
            List<SubordinateTaskItemDto> tasks = tasksByUser.getOrDefault(row.userId(), List.of());
            int inProgress = (int) tasks.stream()
                    .filter(task -> "IN_PROGRESS".equals(task.executionStatus())).count();
            int completed = (int) tasks.stream()
                    .filter(task -> "COMPLETED".equals(task.executionStatus())).count();
            int openIssues = tasks.stream().mapToInt(SubordinateTaskItemDto::openIssueCount).sum();
            return new SubordinateSummaryDto(row.userId(), row.username(), row.realName(), row.roleCode(),
                    row.departmentId(), row.departmentName(), row.teamId(), row.teamName(),
                    tasks.size(), inProgress, completed, openIssues, tasks);
        }).toList();
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
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
        // 直接派发不允许绕过审核：接收人包含上级时必须走派发申请。
        if (requiresApproval(currentUser, assigneeIds)) {
            throw new BusinessException(ErrorCode.DISPATCH_REQUIRES_APPROVAL);
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
        auditTrail.success("派发任务", "TASK", taskId, AuditTrail.USER,
                "直接派发任务 #" + taskId + "，接收人 " + assigneeIds.size() + " 人", List.of());
        return new DispatchResultDto(taskId, assigneeIds.size());
    }

    @Transactional
    public DispatchRequestResultDto dispatchRequest(DispatchRequestDto request) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        DispatchValues values = validateDispatchValues(request == null ? null : request.name(),
                request == null ? null : request.details(),
                request == null ? null : request.startDate(),
                request == null ? null : request.deadline(),
                request == null ? null : request.urgency(),
                request == null ? null : request.taskType(),
                request == null ? null : request.assigneeIds());
        Set<Long> allowed = allowedRecipientIds(currentUser);
        if (!allowed.containsAll(values.assigneeIds())) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }

        // 派发给下级或同级不需要审核，直接生成任务；只有接收人包含上级时才进入审核流程。
        if (!requiresApproval(currentUser, values.assigneeIds())) {
            Long taskId = createTask(currentUser.id(), values, values.assigneeIds());
            auditTrail.success("提交派发申请", "TASK", taskId, AuditTrail.USER,
                    "无需审核，直接派发生效，任务 #" + taskId, List.of());
            return new DispatchRequestResultDto(null, null, taskId, "APPROVED",
                    values.assigneeIds().size());
        }

        Long requestId = jdbcTemplate.queryForObject(
                "INSERT INTO task_dispatch_requests (requester_id, name, details, start_date, deadline, "
                        + "urgency, task_type) VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Long.class, currentUser.id(), values.name(), values.details(), values.startDate(),
                values.deadline(), values.urgency(), values.taskType());
        insertDispatchAssignees(requestId, values.assigneeIds());
        auditTrail.success("提交派发申请", "TASK", requestId, AuditTrail.USER,
                "提交派发申请 #" + requestId + "，等待审核", List.of());

        return new DispatchRequestResultDto(requestId, requestId, null, "PENDING",
                values.assigneeIds().size());
    }

    @Transactional
    public DispatchRequestViewDto updateDispatchRequest(Long requestId, DispatchRequestDto request) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        DispatchRequestViewDto existing = requireDispatchRequest(requestId);
        if (!existing.requesterId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        DispatchValues values = validateDispatchValues(request == null ? null : request.name(),
                request == null ? null : request.details(),
                request == null ? null : request.startDate(),
                request == null ? null : request.deadline(),
                request == null ? null : request.urgency(),
                request == null ? null : request.taskType(),
                request == null ? null : request.assigneeIds());
        Set<Long> allowed = allowedRecipientIds(currentUser);
        if (!allowed.containsAll(values.assigneeIds())) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
        jdbcTemplate.update(
                "UPDATE task_dispatch_requests SET name = ?, details = ?, start_date = ?, deadline = ?, "
                        + "urgency = ?, task_type = ?, updated_at = now() WHERE id = ? AND status = 'PENDING'",
                values.name(), values.details(), values.startDate(), values.deadline(), values.urgency(),
                values.taskType(), requestId);
        jdbcTemplate.update("DELETE FROM task_dispatch_request_assignees WHERE request_id = ?", requestId);
        insertDispatchAssignees(requestId, values.assigneeIds());
        auditTrail.success("编辑待审派发申请", "TASK", requestId, AuditTrail.USER,
                "编辑待审派发申请 #" + requestId,
                valueChanges(existing.name(), existing.details(), existing.startDate(), existing.deadline(),
                        existing.urgency(), existing.taskType(), existing.assigneeIds(), values));
        return requireDispatchRequest(requestId);
    }

    @Transactional
    public DispatchRequestViewDto withdrawDispatchRequest(Long requestId) {
        CurrentUser currentUser = currentUserContext.require();
        DispatchRequestViewDto existing = requireDispatchRequest(requestId);
        if (!existing.requesterId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        jdbcTemplate.update(
                "UPDATE task_dispatch_requests SET status = 'WITHDRAWN', updated_at = now() "
                        + "WHERE id = ? AND status = 'PENDING'",
                requestId);
        auditTrail.success("撤回派发申请", "TASK", requestId, AuditTrail.USER,
                "撤回派发申请 #" + requestId,
                List.of(new AuditChangeDto("status", "PENDING", "WITHDRAWN")));
        return requireDispatchRequest(requestId);
    }

    public PageResult<DispatchRequestViewDto> myDispatchRequests(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        PageQuery pageQuery = PageQuery.of(page, size);
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM task_dispatch_requests WHERE requester_id = ?",
                Long.class, currentUser.id());
        List<DispatchRequestViewDto> items = queryDispatchRequests(
                " WHERE r.requester_id = ? ORDER BY r.created_at DESC, r.id DESC LIMIT ? OFFSET ?",
                currentUser.id(), pageQuery.size(), pageQuery.offset());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public PageResult<DispatchRequestViewDto> reviewableDispatchRequests(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        PageQuery pageQuery = PageQuery.of(page, size);
        ApproverScope scope = approverScope(currentUser);
        if (scope == null) {
            return new PageResult<>(0, pageQuery.page(), pageQuery.size(), List.of());
        }
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM task_dispatch_requests r JOIN users u ON u.id = r.requester_id "
                        + "WHERE r.status = 'PENDING' AND " + scope.condition(),
                Long.class, scope.args());
        List<Object> args = new ArrayList<>(Arrays.asList(scope.args()));
        args.add(pageQuery.size());
        args.add(pageQuery.offset());
        List<DispatchRequestViewDto> items = queryDispatchRequests(
                " JOIN users u ON u.id = r.requester_id WHERE r.status = 'PENDING' AND "
                        + scope.condition() + " ORDER BY r.created_at ASC, r.id ASC LIMIT ? OFFSET ?",
                args.toArray());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    @Transactional
    public DispatchRequestViewDto approveDispatchRequest(Long requestId, ApprovalRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        DispatchRequestViewDto existing = requireDispatchRequest(requestId);
        requireApprover(currentUser, existing.requesterId(), "PENDING".equals(existing.status()));
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        List<Long> assigneeIds = existing.assigneeIds();
        if (assigneeIds.isEmpty()) {
            throw new BusinessException(ErrorCode.INVALID_ASSIGNEES);
        }
        DispatchValues values = new DispatchValues(existing.name(), existing.details(),
                existing.startDate(), existing.deadline(), existing.urgency(), existing.taskType(),
                assigneeIds);
        Long taskId = createTask(existing.requesterId(), values, assigneeIds);
        jdbcTemplate.update(
                "UPDATE task_dispatch_requests SET status = 'APPROVED', reviewer_id = ?, review_comment = ?, "
                        + "reviewed_at = now(), created_task_id = ?, updated_at = now() "
                        + "WHERE id = ? AND status = 'PENDING'",
                currentUser.id(), trim(request == null ? null : request.comment()), taskId, requestId);
        auditTrail.success("通过派发申请", "TASK", requestId, AuditTrail.USER,
                "通过派发申请 #" + requestId + "，生成任务 #" + taskId,
                List.of(new AuditChangeDto("status", "PENDING", "APPROVED")));
        return requireDispatchRequest(requestId);
    }

    @Transactional
    public DispatchRequestViewDto rejectDispatchRequest(Long requestId, ApprovalRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        DispatchRequestViewDto existing = requireDispatchRequest(requestId);
        requireApprover(currentUser, existing.requesterId(), "PENDING".equals(existing.status()));
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        String comment = trim(request == null ? null : request.comment());
        if (comment.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        jdbcTemplate.update(
                "UPDATE task_dispatch_requests SET status = 'REJECTED', reviewer_id = ?, "
                        + "review_comment = ?, reviewed_at = now(), updated_at = now() "
                        + "WHERE id = ? AND status = 'PENDING'",
                currentUser.id(), comment, requestId);
        auditTrail.success("驳回派发申请", "TASK", requestId, AuditTrail.USER,
                "驳回派发申请 #" + requestId,
                List.of(new AuditChangeDto("status", "PENDING", "REJECTED")));
        return requireDispatchRequest(requestId);
    }

    @Transactional
    public ChangeRequestViewDto createChangeRequest(Long taskId, ChangeRequestDto request) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:dispatch")) {
            throw new BusinessException(ErrorCode.NOT_SENDER);
        }
        TaskRef task = requireTaskRef(taskId);
        if (!task.senderId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.NOT_SENDER);
        }
        if (request == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        String action = trim(request.action()).toUpperCase();
        if (!Set.of("UPDATE", "DELETE").contains(action)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        Long pending = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM task_change_requests WHERE task_id = ? AND status = 'PENDING'",
                Long.class, taskId);
        if (pending != null && pending > 0) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }

        DispatchValues values = null;
        if ("UPDATE".equals(action)) {
            values = validateDispatchValues(request.name(), request.details(), request.startDate(),
                    request.deadline(), request.urgency(), request.taskType(), request.assigneeIds());
            Set<Long> allowed = allowedRecipientIds(currentUser);
            if (!allowed.containsAll(values.assigneeIds())) {
                throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
            }
        }

        DispatchValues payload = values;
        TaskValues taskValues = payload == null ? null : requireTaskValues(taskId);
        Long requestId = jdbcTemplate.queryForObject(
                "INSERT INTO task_change_requests (task_id, requester_id, action, name, details, start_date, "
                        + "deadline, urgency, task_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Long.class, taskId, currentUser.id(), action,
                payload == null ? null : payload.name(),
                payload == null ? null : payload.details(),
                payload == null ? null : payload.startDate(),
                payload == null ? null : payload.deadline(),
                payload == null ? null : payload.urgency(),
                payload == null ? null : payload.taskType());
        if (payload != null) {
            insertChangeAssignees(requestId, payload.assigneeIds());
        }
        List<AuditChangeDto> changes = payload == null ? List.of()
                : valueChanges(taskValues.name(), taskValues.details(), taskValues.startDate(),
                        taskValues.deadline(), taskValues.urgency(), taskValues.taskType(),
                        taskValues.assigneeIds(), payload);
        String submitAction = payload == null ? "提交删除申请" : "提交修改申请";
        auditTrail.success(submitAction, "TASK", requestId, AuditTrail.USER,
                submitAction + " #" + requestId + "，任务 #" + taskId, changes);

        // 创始人没有更高上级，直接生效并记录审核人，避免审批死锁。
        if ("FOUNDER".equals(currentUser.roleCode())) {
            ChangeRequestViewDto created = requireChangeRequest(requestId);
            jdbcTemplate.update(
                    "UPDATE task_change_requests SET status = 'APPROVED', reviewer_id = ?, "
                            + "review_comment = '创始人变更自动通过', reviewed_at = now(), updated_at = now() "
                            + "WHERE id = ?",
                    currentUser.id(), requestId);
            ChangeRequestViewDto approved = requireChangeRequest(requestId);
            if ("DELETE".equals(created.action())) {
                jdbcTemplate.update("DELETE FROM tasks WHERE id = ?", created.taskId());
                auditTrail.success("删除任务", "TASK", created.taskId(), AuditTrail.SYSTEM,
                        "创始人变更自动通过，删除任务 #" + created.taskId(), List.of());
            } else {
                applyChangeRequest(approved);
                auditTrail.success("修改任务", "TASK", created.taskId(), AuditTrail.SYSTEM,
                        "创始人变更自动通过，修改任务 #" + created.taskId(), changes);
            }
            // 移动端（feat/pandora-task-workflow-v1.9）对已发布任务的变更只认 PENDING，
            // 因此对外仍返回创建时的待审视图，实际生效结果由任务列表与审计体现。
            return created;
        }
        return requireChangeRequest(requestId);
    }

    public PageResult<ChangeRequestViewDto> reviewableChangeRequests(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        PageQuery pageQuery = PageQuery.of(page, size);
        ApproverScope scope = approverScope(currentUser);
        if (scope == null) {
            return new PageResult<>(0, pageQuery.page(), pageQuery.size(), List.of());
        }
        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM task_change_requests c JOIN users u ON u.id = c.requester_id "
                        + "WHERE c.status = 'PENDING' AND " + scope.condition(),
                Long.class, scope.args());
        List<Object> args = new ArrayList<>(Arrays.asList(scope.args()));
        args.add(pageQuery.size());
        args.add(pageQuery.offset());
        List<ChangeRequestViewDto> items = queryChangeRequests(
                " JOIN users u ON u.id = c.requester_id WHERE c.status = 'PENDING' AND "
                        + scope.condition() + " ORDER BY c.created_at ASC, c.id ASC LIMIT ? OFFSET ?",
                args.toArray());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    @Transactional
    public ChangeRequestViewDto approveChangeRequest(Long requestId, ApprovalRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        ChangeRequestViewDto existing = requireChangeRequest(requestId);
        requireApprover(currentUser, existing.requesterId(), "PENDING".equals(existing.status()));
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        if ("DELETE".equals(existing.action())) {
            // 先改申请状态再删任务：任务删除会级联清理变更申请，顺序反了会丢掉审核结果。
            jdbcTemplate.update(
                    "UPDATE task_change_requests SET status = 'APPROVED', reviewer_id = ?, review_comment = ?, "
                            + "reviewed_at = now(), updated_at = now() WHERE id = ? AND status = 'PENDING'",
                    currentUser.id(), trim(request == null ? null : request.comment()), requestId);
            ChangeRequestViewDto approved = requireChangeRequest(requestId);
            jdbcTemplate.update("DELETE FROM tasks WHERE id = ?", existing.taskId());
            auditTrail.success("通过删除申请", "TASK", requestId, AuditTrail.USER,
                    "通过删除申请 #" + requestId + "，任务 #" + existing.taskId(),
                    List.of(new AuditChangeDto("status", "PENDING", "APPROVED")));
            auditTrail.success("删除任务", "TASK", existing.taskId(), AuditTrail.USER,
                    "审批通过，删除任务 #" + existing.taskId(), List.of());
            return approved;
        }
        TaskValues before = requireTaskValues(existing.taskId());
        List<AuditChangeDto> changes = valueChanges(before.name(), before.details(), before.startDate(),
                before.deadline(), before.urgency(), before.taskType(), before.assigneeIds(), valuesOf(existing));
        applyChangeRequest(existing);
        jdbcTemplate.update(
                "UPDATE task_change_requests SET status = 'APPROVED', reviewer_id = ?, review_comment = ?, "
                        + "reviewed_at = now(), updated_at = now() WHERE id = ? AND status = 'PENDING'",
                currentUser.id(), trim(request == null ? null : request.comment()), requestId);
        changes.add(new AuditChangeDto("status", "PENDING", "APPROVED"));
        auditTrail.success("通过修改申请", "TASK", requestId, AuditTrail.USER,
                "通过修改申请 #" + requestId + "，任务 #" + existing.taskId() + " 已生效", changes);
        return requireChangeRequest(requestId);
    }

    @Transactional
    public ChangeRequestViewDto rejectChangeRequest(Long requestId, ApprovalRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        ChangeRequestViewDto existing = requireChangeRequest(requestId);
        requireApprover(currentUser, existing.requesterId(), "PENDING".equals(existing.status()));
        if (!"PENDING".equals(existing.status())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        String comment = trim(request == null ? null : request.comment());
        if (comment.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        jdbcTemplate.update(
                "UPDATE task_change_requests SET status = 'REJECTED', reviewer_id = ?, review_comment = ?, "
                        + "reviewed_at = now(), updated_at = now() WHERE id = ? AND status = 'PENDING'",
                currentUser.id(), comment, requestId);
        auditTrail.success("DELETE".equals(existing.action()) ? "驳回删除申请" : "驳回修改申请", "TASK", requestId,
                AuditTrail.USER, "驳回变更申请 #" + requestId + "，任务 #" + existing.taskId(),
                List.of(new AuditChangeDto("status", "PENDING", "REJECTED")));
        return requireChangeRequest(requestId);
    }

    private void applyChangeRequest(ChangeRequestViewDto request) {
        TaskRef task = requireTaskRef(request.taskId());
        if (!task.senderId().equals(request.requesterId())) {
            throw new BusinessException(ErrorCode.NOT_SENDER);
        }
        if ("DELETE".equals(request.action())) {
            jdbcTemplate.update("DELETE FROM tasks WHERE id = ?", request.taskId());
            return;
        }

        jdbcTemplate.update(
                "UPDATE tasks SET name = ?, details = ?, start_date = ?, deadline = ?, urgency = ?, "
                        + "task_type = ?, updated_at = now() WHERE id = ?",
                request.name(), request.details(), request.startDate(), request.deadline(),
                request.urgency(), request.taskType(), request.taskId());

        List<Long> assigneeIds = request.assigneeIds();
        for (Long assigneeId : assigneeIds) {
            jdbcTemplate.update(
                    "INSERT INTO task_assignments (task_id, assignee_id) VALUES (?, ?) "
                            + "ON CONFLICT (task_id, assignee_id) DO NOTHING",
                    request.taskId(), assigneeId);
        }
        String placeholders = String.join(",", Collections.nCopies(assigneeIds.size(), "?"));
        List<Object> args = new ArrayList<>();
        args.add(request.taskId());
        args.addAll(assigneeIds);
        // 仅移除尚未开始、没有进度留痕的接收人，避免丢失历史进度与审核记录。
        jdbcTemplate.update(
                "DELETE FROM task_assignments a WHERE a.task_id = ? "
                        + "AND a.assignee_id NOT IN (" + placeholders + ") "
                        + "AND a.execution_status = 'NOT_STARTED' AND a.review_status = 'NONE' "
                        + "AND NOT EXISTS (SELECT 1 FROM task_progress_updates p WHERE p.assignment_id = a.id)",
                args.toArray());
    }

    private TaskRef requireTaskRef(Long taskId) {
        List<TaskRef> rows = jdbcTemplate.query(
                "SELECT id, sender_id FROM tasks WHERE id = ?",
                (rs, index) -> new TaskRef(rs.getLong("id"), rs.getLong("sender_id")),
                taskId);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        return rows.get(0);
    }

    private TaskValues requireTaskValues(Long taskId) {
        List<Long> assigneeIds = jdbcTemplate.queryForList(
                "SELECT assignee_id FROM task_assignments WHERE task_id = ? ORDER BY assignee_id",
                Long.class, taskId);
        return jdbcTemplate.queryForObject(
                "SELECT name, details, start_date, deadline, urgency, task_type FROM tasks WHERE id = ?",
                (rs, index) -> new TaskValues(rs.getString("name"), rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class), rs.getString("urgency"),
                        rs.getString("task_type"), assigneeIds),
                taskId);
    }

    private static DispatchValues valuesOf(ChangeRequestViewDto request) {
        return new DispatchValues(request.name(), request.details(), request.startDate(), request.deadline(),
                request.urgency(), request.taskType(), request.assigneeIds());
    }

    private static List<AuditChangeDto> valueChanges(String name, String details, LocalDateTime startDate,
            LocalDateTime deadline, String urgency, String taskType, List<Long> assigneeIds,
            DispatchValues after) {
        List<AuditChangeDto> changes = new ArrayList<>();
        addChange(changes, "name", name, after.name());
        if (!Objects.equals(details, after.details())) {
            changes.add(new AuditChangeDto("details", "原内容", "新内容"));
        }
        addChange(changes, "startDate", startDate, after.startDate());
        addChange(changes, "deadline", deadline, after.deadline());
        addChange(changes, "urgency", urgency, after.urgency());
        addChange(changes, "taskType", taskType, after.taskType());
        if (!new HashSet<>(assigneeIds == null ? List.of() : assigneeIds)
                .equals(new HashSet<>(after.assigneeIds()))) {
            changes.add(new AuditChangeDto("assignees", String.valueOf(assigneeIds),
                    String.valueOf(after.assigneeIds())));
        }
        return changes;
    }

    private static void addChange(List<AuditChangeDto> changes, String field, Object before, Object after) {
        if (!Objects.equals(before, after)) {
            changes.add(new AuditChangeDto(field, before == null ? null : String.valueOf(before),
                    after == null ? null : String.valueOf(after)));
        }
    }

    private void insertChangeAssignees(Long requestId, List<Long> assigneeIds) {
        for (Long assigneeId : assigneeIds) {
            jdbcTemplate.update(
                    "INSERT INTO task_change_request_assignees (request_id, assignee_id) VALUES (?, ?)",
                    requestId, assigneeId);
        }
    }

    private void insertDispatchAssignees(Long requestId, List<Long> assigneeIds) {
        for (Long assigneeId : assigneeIds) {
            jdbcTemplate.update(
                    "INSERT INTO task_dispatch_request_assignees (request_id, assignee_id) VALUES (?, ?)",
                    requestId, assigneeId);
        }
    }

    public PageResult<DispatchedTaskDto> dispatched(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        requireDispatchPermission(currentUser);
        PageQuery pageQuery = PageQuery.of(page, size);

        Long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM tasks WHERE sender_id = ?", Long.class, currentUser.id());

        List<DispatchedTaskDto> items = jdbcTemplate.query(
                "SELECT t.id, t.name, t.details, t.start_date, t.deadline, t.urgency, t.task_type, t.created_at, "
                        + "COUNT(a.id) AS assignee_count, "
                        + "COUNT(a.id) FILTER (WHERE a.execution_status = 'COMPLETED') AS completed_count, "
                        + "COUNT(a.id) FILTER (WHERE a.review_status = 'PENDING') AS pending_review_count, "
                        + "EXISTS (SELECT 1 FROM task_change_requests c "
                        + "WHERE c.task_id = t.id AND c.status = 'PENDING') AS change_pending "
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
                        rs.getObject("created_at", OffsetDateTime.class),
                        rs.getString("task_type"),
                        rs.getBoolean("change_pending")),
                currentUser.id(), pageQuery.size(), pageQuery.offset());

        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public TaskDetailDto detail(Long taskId) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:dispatch")) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        List<TaskDetailDto> tasks = jdbcTemplate.query(
                "SELECT id, sender_id, name, details, start_date, deadline, urgency, task_type, created_at, updated_at "
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
                        rs.getString("task_type"),
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
                "SELECT a.id, a.assignee_id, u.real_name, a.execution_status, a.review_status, a.updated_at, "
                        + "latest.progress_percent, latest.note AS progress_note, "
                        + "latest.created_at AS progress_updated_at "
                        + "FROM task_assignments a JOIN users u ON u.id = a.assignee_id "
                        + "LEFT JOIN LATERAL (SELECT pu.progress_percent, pu.note, pu.created_at "
                        + "FROM task_progress_updates pu WHERE pu.assignment_id = a.id "
                        + "ORDER BY pu.created_at DESC, pu.id DESC LIMIT 1) latest ON true "
                        + "WHERE a.task_id = ? ORDER BY a.id",
                (rs, index) -> new AssignmentDto(
                        rs.getLong("id"),
                        new AssigneeDto(rs.getLong("assignee_id"), rs.getString("real_name")),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        rs.getObject("updated_at", OffsetDateTime.class),
                        rs.getObject("progress_percent", Integer.class),
                        rs.getString("progress_note"),
                        rs.getObject("progress_updated_at", OffsetDateTime.class)),
                taskId);

        return new TaskDetailDto(task.id(), task.senderId(), task.name(), task.details(),
                task.startDate(), task.deadline(), task.urgency(), task.createdAt(), task.updatedAt(),
                task.taskType(), assignments);
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
                        + "t.urgency, t.task_type, a.execution_status, a.review_status, s.id AS sender_id, "
                        + "s.real_name AS sender_name, a.updated_at, latest.progress_percent, "
                        + "latest.note AS progress_note, latest.created_at AS progress_updated_at, "
                        + "CASE WHEN latest.execution_status = 'BLOCKED' THEN 1 ELSE 0 END AS open_issue_count "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "JOIN users s ON s.id = t.sender_id "
                        + "LEFT JOIN LATERAL (SELECT pu.execution_status, pu.progress_percent, pu.note, pu.created_at "
                        + "FROM task_progress_updates pu WHERE pu.assignment_id = a.id "
                        + "ORDER BY pu.created_at DESC, pu.id DESC LIMIT 1) latest ON true" + where
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
                        rs.getObject("updated_at", OffsetDateTime.class),
                        rs.getString("task_type"),
                        rs.getObject("progress_percent", Integer.class),
                        rs.getString("progress_note"),
                        rs.getObject("progress_updated_at", OffsetDateTime.class),
                        rs.getInt("open_issue_count")),
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
        auditTrail.success("更新进度", "TASK", row.taskId(), AuditTrail.USER,
                "更新任务 #" + row.taskId() + " 进度为 " + target,
                List.of(new AuditChangeDto("executionStatus", row.executionStatus(), target)));
        return state(requireAssignment(assignmentId));
    }

    @Transactional
    public TaskProgressUpdateDto progressUpdate(Long assignmentId, TaskProgressRequest request) {
        CurrentUser currentUser = currentUserContext.require();
        requireExecutePermission(currentUser);
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.NOT_ASSIGNEE);
        }
        if (request == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        String target = trim(request.status()).toUpperCase();
        if (!PROGRESS_STATUSES.contains(target)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if ("PENDING".equals(row.reviewStatus()) || "APPROVED".equals(row.reviewStatus())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        if ("COMPLETED".equals(row.executionStatus())) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }

        ProgressSnapshot latest = latestProgress(assignmentId);
        int currentPercent = latest == null ? 0 : latest.progressPercent();
        Integer percent = request.progressPercent();
        if (percent == null) {
            percent = switch (target) {
                case "NOT_STARTED" -> 0;
                case "COMPLETED" -> 100;
                default -> currentPercent;
            };
        }
        if (percent < 0 || percent > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        if (percent < currentPercent) {
            throw new BusinessException(ErrorCode.TASK_STATUS_CONFLICT);
        }
        if ("COMPLETED".equals(target) && percent != 100) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        if (!"COMPLETED".equals(target) && percent == 100) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        if ("NOT_STARTED".equals(target) && percent != 0) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String note = trim(request.note());
        if (note.length() > 1000) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        if ("BLOCKED".equals(target) && note.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }

        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO task_progress_updates (assignment_id, author_id, execution_status, "
                        + "progress_percent, note) VALUES (?, ?, ?, ?, ?) RETURNING id",
                Long.class, assignmentId, currentUser.id(), target, percent, note);
        jdbcTemplate.update(
                "UPDATE task_assignments SET execution_status = ?, updated_at = now() WHERE id = ?",
                target, assignmentId);
        auditTrail.success("更新进度", "TASK", row.taskId(), AuditTrail.USER,
                "更新任务 #" + row.taskId() + " 进度为 " + target + "（" + percent + "%）",
                List.of(new AuditChangeDto("executionStatus", row.executionStatus(), target),
                        new AuditChangeDto("progressPercent", String.valueOf(currentPercent),
                                String.valueOf(percent))));
        return requireProgressUpdate(id);
    }

    public List<TaskProgressUpdateDto> progressHistory(Long assignmentId) {
        CurrentUser currentUser = currentUserContext.require();
        requireExecutePermission(currentUser);
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(currentUser.id())) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        return queryProgressUpdates(assignmentId);
    }

    public List<TaskProgressUpdateDto> subordinateProgressHistory(Long userId, Long assignmentId) {
        CurrentUser currentUser = currentUserContext.require();
        if (!isSuperiorOf(currentUser, userId)) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        AssignmentRow row = requireAssignment(assignmentId);
        if (!row.assigneeId().equals(userId)) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
        return queryProgressUpdates(assignmentId);
    }

    private TaskProgressUpdateDto requireProgressUpdate(Long id) {
        return jdbcTemplate.queryForObject(
                "SELECT p.id, p.assignment_id, p.execution_status, p.progress_percent, p.note, p.author_id, "
                        + "u.real_name AS author_name, p.created_at FROM task_progress_updates p "
                        + "JOIN users u ON u.id = p.author_id WHERE p.id = ?",
                (rs, index) -> new TaskProgressUpdateDto(
                        rs.getLong("id"),
                        rs.getLong("assignment_id"),
                        rs.getString("execution_status"),
                        rs.getInt("progress_percent"),
                        rs.getString("note"),
                        rs.getLong("author_id"),
                        rs.getString("author_name"),
                        rs.getObject("created_at", OffsetDateTime.class)),
                id);
    }

    private List<TaskProgressUpdateDto> queryProgressUpdates(Long assignmentId) {
        return jdbcTemplate.query(
                "SELECT p.id, p.assignment_id, p.execution_status, p.progress_percent, p.note, p.author_id, "
                        + "u.real_name AS author_name, p.created_at FROM task_progress_updates p "
                        + "JOIN users u ON u.id = p.author_id WHERE p.assignment_id = ? "
                        + "ORDER BY p.created_at ASC, p.id ASC",
                (rs, index) -> new TaskProgressUpdateDto(
                        rs.getLong("id"),
                        rs.getLong("assignment_id"),
                        rs.getString("execution_status"),
                        rs.getInt("progress_percent"),
                        rs.getString("note"),
                        rs.getLong("author_id"),
                        rs.getString("author_name"),
                        rs.getObject("created_at", OffsetDateTime.class)),
                assignmentId);
    }

    private ProgressSnapshot latestProgress(Long assignmentId) {
        List<ProgressSnapshot> rows = jdbcTemplate.query(
                "SELECT execution_status, progress_percent FROM task_progress_updates "
                        + "WHERE assignment_id = ? ORDER BY created_at DESC, id DESC LIMIT 1",
                (rs, index) -> new ProgressSnapshot(
                        rs.getString("execution_status"), rs.getInt("progress_percent")),
                assignmentId);
        return rows.isEmpty() ? null : rows.get(0);
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
        auditTrail.success("申请完成检查", "TASK", row.taskId(), AuditTrail.USER,
                "申请检查任务 #" + row.taskId(),
                List.of(new AuditChangeDto("reviewStatus", row.reviewStatus(), "PENDING")));
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
        auditTrail.success("RETURNED".equals(action) ? "退回检查" : "通过检查", "TASK", row.taskId(),
                AuditTrail.USER, ("RETURNED".equals(action) ? "退回" : "通过") + "检查任务 #" + row.taskId(),
                "RETURNED".equals(action)
                        ? List.of(new AuditChangeDto("reviewStatus", "PENDING", "RETURNED"),
                                new AuditChangeDto("executionStatus", "COMPLETED", "IN_PROGRESS"))
                        : List.of(new AuditChangeDto("reviewStatus", "PENDING", "APPROVED")));
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
                        + "t.urgency, t.task_type, a.execution_status, a.review_status, s.id AS sender_id, "
                        + "s.real_name AS sender_name, latest.progress_percent, latest.note AS progress_note, "
                        + "latest.created_at AS progress_updated_at, "
                        + "CASE WHEN latest.execution_status = 'BLOCKED' THEN 1 ELSE 0 END AS open_issue_count "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "JOIN users s ON s.id = t.sender_id "
                        + "LEFT JOIN LATERAL (SELECT pu.execution_status, pu.progress_percent, pu.note, pu.created_at "
                        + "FROM task_progress_updates pu WHERE pu.assignment_id = a.id "
                        + "ORDER BY pu.created_at DESC, pu.id DESC LIMIT 1) latest ON true WHERE a.id = ?",
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
                        List.of(),
                        rs.getString("task_type"),
                        rs.getObject("progress_percent", Integer.class),
                        rs.getString("progress_note"),
                        rs.getObject("progress_updated_at", OffsetDateTime.class),
                        rs.getInt("open_issue_count")),
                assignmentId);
        AssignmentDetailDto detail = rows.get(0);
        return new AssignmentDetailDto(detail.assignmentId(), detail.taskId(), detail.name(), detail.details(),
                detail.startDate(), detail.deadline(), detail.urgency(), detail.executionStatus(),
                detail.reviewStatus(), detail.sender(), reviews(assignmentId), detail.taskType(),
                detail.progressPercent(), detail.progressNote(), detail.progressUpdatedAt(),
                detail.openIssueCount());
    }

    private void requireApprover(CurrentUser currentUser, Long requesterId, boolean pending) {
        if (!pending || !isSuperiorOf(currentUser, requesterId)) {
            throw new BusinessException(ErrorCode.TASK_ACCESS_DENIED);
        }
    }

    private boolean isSuperiorOf(CurrentUser currentUser, Long targetId) {
        UserRef target = userRef(targetId);
        if (target == null) {
            return false;
        }
        return switch (currentUser.roleCode()) {
            case "FOUNDER" -> !"FOUNDER".equals(target.roleCode());
            case "DEPT_MANAGER" -> Set.of("TEAM_LEADER", "EMPLOYEE").contains(target.roleCode())
                    && java.util.Objects.equals(currentUser.departmentId(), target.departmentId());
            case "TEAM_LEADER" -> "EMPLOYEE".equals(target.roleCode())
                    && java.util.Objects.equals(currentUser.teamId(), target.teamId());
            default -> false;
        };
    }

    /** 接收人包含上级时必须审核；全部是下级或同级时直接派发生效。 */
    private boolean requiresApproval(CurrentUser currentUser, List<Long> assigneeIds) {
        return assigneeIds.stream().anyMatch(assigneeId -> isSuperiorTo(currentUser, assigneeId));
    }

    /** 判断接收人是否为当前用户的上级，与 isSuperiorOf 互为反向。 */
    private boolean isSuperiorTo(CurrentUser currentUser, Long targetId) {
        if (targetId == null || targetId.equals(currentUser.id())) {
            return false;
        }
        UserRef target = userRef(targetId);
        if (target == null) {
            return false;
        }
        if ("FOUNDER".equals(target.roleCode())) {
            return !"FOUNDER".equals(currentUser.roleCode());
        }
        return switch (currentUser.roleCode()) {
            case "EMPLOYEE" -> ("TEAM_LEADER".equals(target.roleCode())
                    && java.util.Objects.equals(currentUser.teamId(), target.teamId()))
                    || ("DEPT_MANAGER".equals(target.roleCode())
                    && java.util.Objects.equals(currentUser.departmentId(), target.departmentId()));
            case "TEAM_LEADER" -> "DEPT_MANAGER".equals(target.roleCode())
                    && java.util.Objects.equals(currentUser.departmentId(), target.departmentId());
            default -> false;
        };
    }

    private UserRef userRef(Long userId) {
        if (userId == null) {
            return null;
        }
        List<UserRef> rows = jdbcTemplate.query(
                "SELECT role_code, department_id, team_id FROM users WHERE id = ? AND status = 'ACTIVE'",
                (rs, index) -> new UserRef(
                        rs.getString("role_code"),
                        rs.getObject("department_id") == null ? null : rs.getLong("department_id"),
                        rs.getObject("team_id") == null ? null : rs.getLong("team_id")),
                userId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private ApproverScope approverScope(CurrentUser currentUser) {
        return switch (currentUser.roleCode()) {
            case "FOUNDER" -> new ApproverScope(
                    "u.role_code IN ('DEPT_MANAGER', 'TEAM_LEADER', 'EMPLOYEE')", new Object[0]);
            case "DEPT_MANAGER" -> new ApproverScope(
                    "u.role_code IN ('TEAM_LEADER', 'EMPLOYEE') AND u.department_id = ?",
                    new Object[] { currentUser.departmentId() });
            case "TEAM_LEADER" -> new ApproverScope(
                    "u.role_code = 'EMPLOYEE' AND u.team_id = ?",
                    new Object[] { currentUser.teamId() });
            default -> null;
        };
    }

    private DispatchValues validateDispatchValues(String rawName, String rawDetails, String rawStartDate,
            String rawDeadline, String rawUrgency, String rawTaskType, List<Long> rawAssigneeIds) {
        String name = trim(rawName);
        if (name.isEmpty() || name.length() > 200) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String details = trim(rawDetails);
        if (details.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        LocalDateTime startDate = parseTaskDate(rawStartDate, false);
        LocalDateTime deadline = parseTaskDate(rawDeadline, true);
        if (!deadline.isAfter(startDate)) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String urgency = trim(rawUrgency).toUpperCase();
        if (!URGENCIES.contains(urgency)) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        String taskType = trim(rawTaskType);
        taskType = taskType.isEmpty() ? "GENERAL" : taskType.toUpperCase();
        if (!TASK_TYPES.contains(taskType)) {
            throw new BusinessException(ErrorCode.TASK_VALIDATION_FAILED);
        }
        List<Long> assigneeIds = rawAssigneeIds;
        if (assigneeIds == null || assigneeIds.isEmpty()
                || assigneeIds.stream().anyMatch(id -> id == null || id <= 0)) {
            throw new BusinessException(ErrorCode.INVALID_ASSIGNEES);
        }
        if (new HashSet<>(assigneeIds).size() != assigneeIds.size()) {
            throw new BusinessException(ErrorCode.INVALID_ASSIGNEES);
        }
        return new DispatchValues(name, details, startDate, deadline, urgency, taskType,
                List.copyOf(assigneeIds));
    }

    private Long createTask(Long senderId, DispatchValues values, List<Long> assigneeIds) {
        Long taskId = jdbcTemplate.queryForObject(
                "INSERT INTO tasks (sender_id, name, details, start_date, deadline, urgency, task_type) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id",
                Long.class, senderId, values.name(), values.details(), values.startDate(),
                values.deadline(), values.urgency(), values.taskType());
        for (Long assigneeId : assigneeIds) {
            jdbcTemplate.update(
                    "INSERT INTO task_assignments (task_id, assignee_id) VALUES (?, ?)",
                    taskId, assigneeId);
        }
        return taskId;
    }

    private DispatchRequestViewDto requireDispatchRequest(Long requestId) {
        List<DispatchRequestViewDto> rows = queryDispatchRequests(
                " WHERE r.id = ?", requestId);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        return rows.get(0);
    }

    private List<DispatchRequestViewDto> queryDispatchRequests(String tail, Object... args) {
        List<DispatchRequestRow> rows = jdbcTemplate.query(
                "SELECT r.id, r.requester_id, ru.real_name AS requester_name, r.name, r.details, "
                        + "r.start_date, r.deadline, r.urgency, r.task_type, r.status, r.reviewer_id, "
                        + "rv.real_name AS reviewer_name, r.review_comment, r.reviewed_at, r.created_task_id, "
                        + "r.created_at, r.updated_at, "
                        + "CASE WHEN r.created_task_id IS NOT NULL AND EXISTS (SELECT 1 FROM task_change_requests c "
                        + "WHERE c.task_id = r.created_task_id AND c.status = 'PENDING') "
                        + "THEN 'PENDING' ELSE NULL END AS change_status "
                        + "FROM task_dispatch_requests r JOIN users ru ON ru.id = r.requester_id "
                        + "LEFT JOIN users rv ON rv.id = r.reviewer_id" + tail,
                (rs, index) -> new DispatchRequestRow(
                        rs.getLong("id"),
                        rs.getLong("requester_id"),
                        rs.getString("requester_name"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("task_type"),
                        rs.getString("status"),
                        rs.getObject("reviewer_id") == null ? null : rs.getLong("reviewer_id"),
                        rs.getString("reviewer_name"),
                        rs.getString("review_comment"),
                        rs.getObject("reviewed_at", OffsetDateTime.class),
                        rs.getObject("created_task_id") == null ? null : rs.getLong("created_task_id"),
                        rs.getObject("created_at", OffsetDateTime.class),
                        rs.getObject("updated_at", OffsetDateTime.class),
                        rs.getString("change_status")),
                args);
        return rows.stream().map(this::toDispatchView).toList();
    }

    private DispatchRequestViewDto toDispatchView(DispatchRequestRow row) {
        List<Long> assigneeIds = jdbcTemplate.queryForList(
                "SELECT assignee_id FROM task_dispatch_request_assignees WHERE request_id = ? "
                        + "ORDER BY assignee_id",
                Long.class, row.id());
        return new DispatchRequestViewDto(row.id(), row.id(), row.createdTaskId(), row.name(),
                row.details(), row.startDate(), row.deadline(), row.urgency(), row.taskType(),
                assigneeIds, assigneeIds.size(), row.status(), row.requesterId(), row.requesterName(),
                row.reviewerId(), row.reviewerName(), row.reviewComment(), row.reviewedAt(),
                row.createdAt(), row.updatedAt(), row.changeStatus(),
                "PENDING".equals(row.changeStatus()));
    }

    private ChangeRequestViewDto requireChangeRequest(Long requestId) {
        List<ChangeRequestViewDto> rows = queryChangeRequests(" WHERE c.id = ?", requestId);
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.TASK_NOT_FOUND);
        }
        return rows.get(0);
    }

    private List<ChangeRequestViewDto> queryChangeRequests(String tail, Object... args) {
        List<ChangeRequestRow> rows = jdbcTemplate.query(
                "SELECT c.id, c.task_id, c.requester_id, ru.real_name AS requester_name, c.action, "
                        + "c.name, c.details, c.start_date, c.deadline, c.urgency, c.task_type, c.status, "
                        + "c.reviewer_id, rv.real_name AS reviewer_name, c.review_comment, c.reviewed_at, "
                        + "c.created_at, c.updated_at "
                        + "FROM task_change_requests c JOIN users ru ON ru.id = c.requester_id "
                        + "LEFT JOIN users rv ON rv.id = c.reviewer_id" + tail,
                (rs, index) -> new ChangeRequestRow(
                        rs.getLong("id"),
                        rs.getLong("task_id"),
                        rs.getLong("requester_id"),
                        rs.getString("requester_name"),
                        rs.getString("action"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("task_type"),
                        rs.getString("status"),
                        rs.getObject("reviewer_id") == null ? null : rs.getLong("reviewer_id"),
                        rs.getString("reviewer_name"),
                        rs.getString("review_comment"),
                        rs.getObject("reviewed_at", OffsetDateTime.class),
                        rs.getObject("created_at", OffsetDateTime.class),
                        rs.getObject("updated_at", OffsetDateTime.class)),
                args);
        return rows.stream().map(this::toChangeView).toList();
    }

    private ChangeRequestViewDto toChangeView(ChangeRequestRow row) {
        List<Long> assigneeIds = jdbcTemplate.queryForList(
                "SELECT assignee_id FROM task_change_request_assignees WHERE request_id = ? "
                        + "ORDER BY assignee_id",
                Long.class, row.id());
        return new ChangeRequestViewDto(row.id(), row.taskId(), row.action(), row.name(), row.details(),
                row.startDate(), row.deadline(), row.urgency(), row.taskType(), assigneeIds,
                assigneeIds.size(), row.status(), row.requesterId(), row.requesterName(),
                row.reviewerId(), row.reviewerName(), row.reviewComment(), row.reviewedAt(),
                row.createdAt(), row.updatedAt());
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

    private RecipientQuery recipientQuery(CurrentUser currentUser) {
        // 派发范围放宽到全公司：同公司内除本人和管理员外的在职成员均可接收。
        Long companyId = companyIdOf(currentUser);
        if (companyId == null) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
        return new RecipientQuery(
                "u.status = 'ACTIVE' AND u.id <> ? AND u.role_code <> 'ADMIN' "
                        + "AND (u.department_id IN (SELECT d.id FROM departments d WHERE d.company_id = ?) "
                        + "OR u.id = (SELECT c.founder_id FROM companies c WHERE c.id = ?))",
                new Object[] { currentUser.id(), companyId, companyId });
    }

    /** 解析当前用户所属公司；创始人通过企业表反查，其余角色沿部门/团队上溯。 */
    private Long companyIdOf(CurrentUser currentUser) {
        return switch (currentUser.roleCode()) {
            case "FOUNDER" -> firstId("SELECT id FROM companies WHERE founder_id = ?", currentUser.id());
            case "DEPT_MANAGER" -> firstId("SELECT company_id FROM departments WHERE id = ?",
                    currentUser.departmentId());
            case "TEAM_LEADER", "EMPLOYEE" -> firstId(
                    "SELECT d.company_id FROM teams t JOIN departments d ON d.id = t.department_id "
                            + "WHERE t.id = ?", currentUser.teamId());
            default -> null;
        };
    }

    private Long firstId(String sql, Long argument) {
        if (argument == null) {
            return null;
        }
        List<Long> ids = jdbcTemplate.queryForList(sql, Long.class, argument);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private SubordinateScope subordinateScope(CurrentUser currentUser) {
        return switch (currentUser.roleCode()) {
            case "FOUNDER" -> new SubordinateScope(
                    "u.status = 'ACTIVE' AND u.id <> ? "
                            + "AND u.role_code IN ('DEPT_MANAGER', 'TEAM_LEADER', 'EMPLOYEE')",
                    new Object[] { currentUser.id() });
            case "DEPT_MANAGER" -> new SubordinateScope(
                    "u.status = 'ACTIVE' AND u.department_id = ? "
                            + "AND u.role_code IN ('TEAM_LEADER', 'EMPLOYEE')",
                    new Object[] { currentUser.departmentId() });
            case "TEAM_LEADER" -> new SubordinateScope(
                    "u.status = 'ACTIVE' AND u.team_id = ? AND u.role_code = 'EMPLOYEE'",
                    new Object[] { currentUser.teamId() });
            default -> null;
        };
    }

    private Set<Long> allowedRecipientIds(CurrentUser currentUser) {
        RecipientQuery query = recipientQuery(currentUser);
        return new HashSet<>(jdbcTemplate.queryForList(
                "SELECT u.id FROM users u WHERE " + query.filter(), Long.class, query.args()));
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

    private record RecipientQuery(String filter, Object[] args) {
    }

    private record SubordinateScope(String condition, Object[] args) {
    }

    private record ApproverScope(String condition, Object[] args) {
    }

    private record DispatchValues(String name, String details, LocalDateTime startDate,
            LocalDateTime deadline, String urgency, String taskType, List<Long> assigneeIds) {
    }

    private record TaskRef(Long id, Long senderId) {
    }

    private record TaskValues(String name, String details, LocalDateTime startDate, LocalDateTime deadline,
            String urgency, String taskType, List<Long> assigneeIds) {
    }

    private record ProgressSnapshot(String executionStatus, int progressPercent) {
    }

    private record UserRef(String roleCode, Long departmentId, Long teamId) {
    }

    private record DispatchRequestRow(Long id, Long requesterId, String requesterName, String name,
            String details, LocalDateTime startDate, LocalDateTime deadline, String urgency,
            String taskType, String status, Long reviewerId, String reviewerName, String reviewComment,
            OffsetDateTime reviewedAt, Long createdTaskId, OffsetDateTime createdAt,
            OffsetDateTime updatedAt, String changeStatus) {
    }

    private record ChangeRequestRow(Long id, Long taskId, Long requesterId, String requesterName,
            String action, String name, String details, LocalDateTime startDate, LocalDateTime deadline,
            String urgency, String taskType, String status, Long reviewerId, String reviewerName,
            String reviewComment, OffsetDateTime reviewedAt, OffsetDateTime createdAt,
            OffsetDateTime updatedAt) {
    }

    private record SubordinateRow(Long userId, String username, String realName, String roleCode,
            Long departmentId, String departmentName, Long teamId, String teamName) {
    }

    private record SubordinateTaskRow(Long assignmentId, Long assigneeId, Long taskId, String name,
            String details, LocalDateTime startDate, LocalDateTime deadline, String urgency,
            String taskType, String executionStatus, String reviewStatus, Long senderId, String senderName,
            String assigneeName, OffsetDateTime updatedAt, Integer progressPercent, String progressNote,
            OffsetDateTime progressUpdatedAt, int openIssueCount) {

        private SubordinateTaskItemDto toItem() {
            return new SubordinateTaskItemDto(assignmentId, taskId, name, details, startDate, deadline,
                    urgency, executionStatus, reviewStatus, new AssigneeDto(senderId, senderName),
                    new AssigneeDto(assigneeId, assigneeName), updatedAt, taskType, progressPercent,
                    progressNote, progressUpdatedAt, openIssueCount);
        }
    }

    private record AssignmentRow(Long id, Long taskId, Long assigneeId, Long senderId,
            String executionStatus, String reviewStatus) {
    }
}
