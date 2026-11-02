package com.pandora.log.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.dto.MobileDtos.CalendarDayDto;
import com.pandora.log.dto.MobileDtos.CalendarDto;
import com.pandora.log.dto.MobileDtos.CalendarLogDto;
import com.pandora.log.dto.MobileDtos.CalendarTaskDto;
import com.pandora.log.dto.MobileDtos.TaskMapDto;
import com.pandora.log.dto.MobileDtos.TaskMapItemDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class CalendarService {

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public CalendarService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public CalendarDto calendar(String from, String to) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:execute")) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
        LocalDate fromDate = parseDate(from);
        LocalDate toDate = parseDate(to);
        if (fromDate.isAfter(toDate) || ChronoUnit.DAYS.between(fromDate, toDate) > 30) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }

        Scope scope = logScope(currentUser);
        List<LogRow> logs = jdbcTemplate.query(
                "SELECT l.id, l.author_id, l.log_date, l.status FROM work_logs l "
                        + "JOIN users u ON u.id = l.author_id WHERE l.log_date BETWEEN ? AND ? AND "
                        + scope.condition() + " ORDER BY l.log_date, l.id",
                (rs, index) -> new LogRow(
                        rs.getObject("log_date", LocalDate.class),
                        rs.getLong("id"),
                        rs.getLong("author_id"),
                        rs.getString("status")),
                prepend(fromDate, toDate, scope.arguments()));

        List<TaskRow> tasks = jdbcTemplate.query(
                "SELECT t.id AS task_id, a.id AS assignment_id, t.name, a.execution_status, a.review_status, "
                        + "t.start_date, t.deadline FROM task_assignments a JOIN tasks t ON t.id = a.task_id "
                        + "WHERE a.assignee_id = ? AND t.start_date < ? AND t.deadline >= ? "
                        + "ORDER BY t.deadline, t.id",
                (rs, index) -> new TaskRow(
                        rs.getLong("task_id"),
                        rs.getLong("assignment_id"),
                        rs.getString("name"),
                        rs.getString("execution_status"),
                        rs.getString("review_status"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class)),
                currentUser.id(), toDate.plusDays(1).atStartOfDay(), fromDate.atStartOfDay());

        Map<LocalDate, List<CalendarLogDto>> logsByDate = logs.stream().collect(Collectors.groupingBy(
                LogRow::date,
                Collectors.mapping(row -> new CalendarLogDto(row.id(), row.authorId(), row.status()),
                        Collectors.toList())));

        List<CalendarDayDto> days = new ArrayList<>();
        for (LocalDate date = fromDate; !date.isAfter(toDate); date = date.plusDays(1)) {
            LocalDate current = date;
            List<CalendarLogDto> dayLogs = logsByDate.getOrDefault(current, List.of());
            List<CalendarTaskDto> dayTasks = tasks.stream()
                    .filter(task -> !current.isBefore(task.startDate().toLocalDate()) && !current.isAfter(task.deadline().toLocalDate()))
                    .map(task -> new CalendarTaskDto(task.taskId(), task.assignmentId(), task.name(),
                            task.executionStatus(), task.reviewStatus()))
                    .toList();
            String mark = !dayTasks.isEmpty() ? "GREEN" : (!dayLogs.isEmpty() ? "RED" : "NONE");
            days.add(new CalendarDayDto(date, dayLogs.size(), dayTasks.size(), mark, dayLogs, dayTasks));
        }
        return new CalendarDto(days);
    }

    public TaskMapDto taskMap(Integer page, Integer size) {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("task:execute") && !currentUser.hasPermission("task:self")) {
            throw new BusinessException(ErrorCode.CANNOT_DISPATCH);
        }
        PageQuery pageQuery = PageQuery.of(page, size);

        Long total = jdbcTemplate.queryForObject(
                "SELECT (SELECT COUNT(*) FROM task_assignments WHERE assignee_id = ?) "
                        + "+ (SELECT COUNT(*) FROM personal_tasks WHERE owner_id = ?)",
                Long.class, currentUser.id(), currentUser.id());

        List<TaskMapItemDto> items = jdbcTemplate.query(
                "SELECT * FROM ("
                        + "SELECT 'DISPATCHED' AS source, t.id AS task_id, a.id AS assignment_id, "
                        + "CAST(NULL AS BIGINT) AS personal_task_id, t.name, t.details, t.start_date, t.deadline, t.urgency, "
                        + "a.execution_status, a.review_status, a.updated_at "
                        + "FROM task_assignments a JOIN tasks t ON t.id = a.task_id WHERE a.assignee_id = ? "
                        + "UNION ALL "
                        + "SELECT 'PERSONAL' AS source, CAST(NULL AS BIGINT) AS task_id, "
                        + "CAST(NULL AS BIGINT) AS assignment_id, p.id AS personal_task_id, p.name, p.details, "
                        + "CAST(NULL AS TIMESTAMP) AS start_date, CAST(NULL AS TIMESTAMP) AS deadline, CAST(NULL AS VARCHAR) AS urgency, p.status AS execution_status, "
                        + "CAST(NULL AS VARCHAR) AS review_status, p.updated_at "
                        + "FROM personal_tasks p WHERE p.owner_id = ?"
                        + ") m ORDER BY m.updated_at DESC, m.source, m.name LIMIT ? OFFSET ?",
                (rs, index) -> new TaskMapItemDto(
                        rs.getString("source"),
                        rs.getObject("task_id") == null ? null : rs.getLong("task_id"),
                        rs.getObject("assignment_id") == null ? null : rs.getLong("assignment_id"),
                        rs.getObject("personal_task_id") == null ? null : rs.getLong("personal_task_id"),
                        rs.getString("name"),
                        rs.getString("details"),
                        rs.getObject("start_date", LocalDateTime.class),
                        rs.getObject("deadline", LocalDateTime.class),
                        rs.getString("urgency"),
                        rs.getString("execution_status"),
                        rs.getString("review_status")),
                currentUser.id(), currentUser.id(), pageQuery.size(), pageQuery.offset());

        return new TaskMapDto(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    private static Object[] prepend(LocalDate from, LocalDate to, List<Object> rest) {
        List<Object> args = new ArrayList<>();
        args.add(from);
        args.add(to);
        args.addAll(rest);
        return args.toArray();
    }

    private LocalDate parseDate(String value) {
        try {
            return LocalDate.parse(value == null ? "" : value.trim());
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
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

    private record Scope(String condition, List<Object> arguments) {
    }

    private record LogRow(LocalDate date, Long id, Long authorId, String status) {
    }

    private record TaskRow(Long taskId, Long assignmentId, String name, String executionStatus,
            String reviewStatus, LocalDateTime startDate, LocalDateTime deadline) {
    }
}
