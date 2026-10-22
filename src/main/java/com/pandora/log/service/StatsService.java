package com.pandora.log.service;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.MobileDtos.OverviewDto;
import com.pandora.log.dto.MobileDtos.TrendPointDto;
import com.pandora.log.dto.MobileDtos.UnsubmittedUserDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class StatsService {

    private static final ZoneId ZONE = ZoneId.of("Asia/Shanghai");

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;

    public StatsService(JdbcTemplate jdbcTemplate, CurrentUserContext currentUserContext) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
    }

    public OverviewDto overview() {
        CurrentUser currentUser = currentUserContext.require();
        requireStatsPermission(currentUser);
        LocalDate today = LocalDate.now(ZONE);
        Scope scope = userScope(currentUser);

        Long expected = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users u WHERE u.status = 'ACTIVE' AND u.role_code <> 'ADMIN' AND "
                        + scope.condition(),
                Long.class, scope.arguments().toArray());
        Long submitted = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users u JOIN work_logs l ON l.author_id = u.id "
                        + "WHERE l.log_date = ? AND l.status = 'SUBMITTED' AND u.status = 'ACTIVE' "
                        + "AND u.role_code <> 'ADMIN' AND " + scope.condition(),
                Long.class, prepend(today, scope.arguments()).toArray());

        int expectedCount = expected == null ? 0 : expected.intValue();
        int submittedCount = submitted == null ? 0 : submitted.intValue();
        int unsubmitted = Math.max(expectedCount - submittedCount, 0);
        double rate = expectedCount == 0 ? 0 : Math.round(submittedCount * 1000.0 / expectedCount) / 10.0;
        return new OverviewDto(expectedCount, submittedCount, unsubmitted, rate);
    }

    public List<UnsubmittedUserDto> unsubmitted() {
        CurrentUser currentUser = currentUserContext.require();
        requireStatsPermission(currentUser);
        LocalDate today = LocalDate.now(ZONE);
        Scope scope = userScope(currentUser);
        List<Object> args = new ArrayList<>(scope.arguments());
        args.add(today);
        return jdbcTemplate.query(
                "SELECT u.id, u.username, u.real_name FROM users u "
                        + "WHERE u.status = 'ACTIVE' AND u.role_code <> 'ADMIN' AND " + scope.condition()
                        + " AND NOT EXISTS (SELECT 1 FROM work_logs l WHERE l.author_id = u.id "
                        + "AND l.log_date = ? AND l.status = 'SUBMITTED') ORDER BY u.id",
                (rs, index) -> new UnsubmittedUserDto(
                        rs.getLong("id"), rs.getString("username"), rs.getString("real_name")),
                args.toArray());
    }

    public List<TrendPointDto> trend(Integer days) {
        CurrentUser currentUser = currentUserContext.require();
        requireStatsPermission(currentUser);
        if (days == null) {
            days = 7;
        }
        if (days != 7 && days != 30) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
        LocalDate today = LocalDate.now(ZONE);
        LocalDate from = today.minusDays(days - 1L);
        Scope scope = userScope(currentUser);

        List<Object> args = new ArrayList<>();
        args.add(from);
        args.add(today);
        args.addAll(scope.arguments());
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT l.log_date AS log_date, COUNT(*) AS log_count FROM work_logs l "
                        + "JOIN users u ON u.id = l.author_id "
                        + "WHERE l.log_date BETWEEN ? AND ? AND l.status = 'SUBMITTED' AND " + scope.condition()
                        + " GROUP BY l.log_date ORDER BY l.log_date",
                args.toArray());

        Map<LocalDate, Integer> counts = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            LocalDate date = ((java.sql.Date) row.get("log_date")).toLocalDate();
            counts.put(date, ((Number) row.get("log_count")).intValue());
        }

        List<TrendPointDto> points = new ArrayList<>();
        for (LocalDate date = from; !date.isAfter(today); date = date.plusDays(1)) {
            points.add(new TrendPointDto(date, counts.getOrDefault(date, 0)));
        }
        return points;
    }

    private void requireStatsPermission(CurrentUser currentUser) {
        if (!currentUser.hasPermission("stats:read")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private static Scope userScope(CurrentUser currentUser) {
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
