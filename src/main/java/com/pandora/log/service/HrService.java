package com.pandora.log.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.common.PageQuery;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.CrmDtos.ActivityDto;
import com.pandora.log.dto.CrmDtos.CreateEmployeeArchiveRequest;
import com.pandora.log.dto.CrmDtos.EmployeeArchiveDto;
import com.pandora.log.security.CurrentUserContext;
import com.pandora.log.service.CrmService.Scope;

@Service
public class HrService {
    private static final Set<String> EMPLOYEE_ROLES =
            Set.of("FOUNDER", "DEPT_MANAGER", "TEAM_LEADER", "EMPLOYEE");
    private final JdbcTemplate jdbc;
    private final CurrentUserContext context;
    private final AuditTrail audit;
    private final CrmService crm;

    public HrService(JdbcTemplate jdbc, CurrentUserContext context, AuditTrail audit, CrmService crm) {
        this.jdbc = jdbc;
        this.context = context;
        this.audit = audit;
        this.crm = crm;
    }

    public PageResult<EmployeeArchiveDto> employees(String keyword, Long departmentId, String role,
            Integer contractExpiringDays, Integer page, Integer size) {
        CurrentUser user = require("hr:read");
        PageQuery pq = PageQuery.of(page, size);
        Scope scope = employeeScope(user, "u");
        StringBuilder where = new StringBuilder(" WHERE u.role_code<>'ADMIN' AND ").append(scope.sql());
        List<Object> args = new ArrayList<>(scope.args());
        if (keyword != null && !keyword.isBlank()) {
            where.append(" AND (u.real_name ILIKE ? OR u.username ILIKE ? OR COALESCE(p.duty,'') ILIKE ? OR COALESCE(d.name,'') ILIKE ?)");
            String pattern = "%" + keyword.trim() + "%";
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
        }
        if (departmentId != null) {
            where.append(" AND u.department_id=?");
            args.add(departmentId);
        }
        if (role != null && !role.isBlank()) {
            String value = role.trim().toUpperCase();
            if (!EMPLOYEE_ROLES.contains(value)) invalid("role 非法");
            where.append(" AND u.role_code=?");
            args.add(value);
        }
        if (contractExpiringDays != null) {
            int days = Math.max(0, Math.min(contractExpiringDays, 365));
            where.append(" AND u.status='ACTIVE' AND p.contract_end BETWEEN CURRENT_DATE AND CURRENT_DATE+?");
            args.add(days);
        }
        String from = " FROM users u LEFT JOIN departments d ON d.id=u.department_id " +
                "LEFT JOIN hr_employee_profiles p ON p.user_id=u.id";
        Long total = jdbc.queryForObject("SELECT COUNT(*)" + from + where, Long.class, args.toArray());
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pq.size());
        pageArgs.add(pq.offset());
        List<EmployeeArchiveDto> rows = jdbc.query(
                "SELECT u.id,u.department_id,u.real_name,d.name AS department_name,u.role_code,u.status," +
                        "COALESCE(p.duty,'') AS duty,p.contract_end," +
                        "COALESCE(p.contract_archive_status,'MISSING') AS contract_archive_status" +
                        from + where + " ORDER BY u.id LIMIT ? OFFSET ?",
                (rs, i) -> employeeDto(rs, user), pageArgs.toArray());
        return new PageResult<>(total == null ? 0 : total, pq.page(), pq.size(), rows);
    }

    @Transactional
    public EmployeeArchiveDto createEmployee(CreateEmployeeArchiveRequest request) {
        CurrentUser user = require("hr:write");
        if (request == null) invalid("员工档案不能为空");
        String duty = request.duty() == null ? "" : request.duty().trim();
        if (duty.isEmpty() || duty.length() > 500) invalid("岗位职责不能为空且不能超过 500 字");
        Long userId = resolveUser(request);
        String archive = request.contractArchiveStatus() == null || request.contractArchiveStatus().isBlank()
                ? "MISSING" : request.contractArchiveStatus().trim().toUpperCase();
        if (!Set.of("MISSING", "PENDING", "ARCHIVED").contains(archive)) {
            invalid("合同归档状态非法");
        }
        jdbc.update("INSERT INTO hr_employee_profiles(user_id,duty,contract_end,contract_archive_status,updated_by) " +
                "VALUES (?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET duty=EXCLUDED.duty," +
                "contract_end=EXCLUDED.contract_end,contract_archive_status=EXCLUDED.contract_archive_status," +
                "updated_by=EXCLUDED.updated_by,updated_at=now()",
                userId, duty, request.contractEnd(), archive, user.id());
        audit.success("维护员工档案", "HR_EMPLOYEE", userId, AuditTrail.USER,
                "更新人员档案元数据", List.of());
        return requireEmployee(userId, user);
    }

    public List<ActivityDto> employeeActivities(Long employeeId) {
        CurrentUser user = require("hr:read");
        requireEmployee(employeeId, user);
        if (!user.hasPermission("crm:read")) return List.of();
        Scope customerScope = crm.customerScope(user, "c");
        List<Object> args = new ArrayList<>();
        args.add(employeeId);
        args.addAll(customerScope.args());
        List<Long> ids = jdbc.queryForList(
                "SELECT a.id FROM crm_activities a JOIN crm_activity_participants p ON p.activity_id=a.id " +
                        "JOIN crm_customers c ON c.id=a.customer_id WHERE p.employee_id=? AND " +
                        customerScope.sql() + " ORDER BY a.activity_date DESC,a.id DESC",
                Long.class, args.toArray());
        if (ids.isEmpty()) return List.of();
        String marks = String.join(",", Collections.nCopies(ids.size(), "?"));
        return crm.loadActivities("a.id IN (" + marks + ")", ids.toArray());
    }

    private EmployeeArchiveDto requireEmployee(Long id, CurrentUser user) {
        Scope scope = employeeScope(user, "u");
        List<Object> args = new ArrayList<>();
        args.add(id);
        args.addAll(scope.args());
        List<EmployeeArchiveDto> rows = jdbc.query(
                "SELECT u.id,u.department_id,u.real_name,d.name AS department_name,u.role_code,u.status," +
                        "COALESCE(p.duty,'') AS duty,p.contract_end," +
                        "COALESCE(p.contract_archive_status,'MISSING') AS contract_archive_status " +
                        "FROM users u LEFT JOIN departments d ON d.id=u.department_id " +
                        "LEFT JOIN hr_employee_profiles p ON p.user_id=u.id " +
                        "WHERE u.id=? AND u.role_code<>'ADMIN' AND " + scope.sql(),
                (rs, i) -> employeeDto(rs, user), args.toArray());
        if (rows.isEmpty()) throw new BusinessException(ErrorCode.RESOURCE_NOT_VISIBLE);
        return rows.get(0);
    }

    private EmployeeArchiveDto employeeDto(java.sql.ResultSet rs, CurrentUser viewer)
            throws java.sql.SQLException {
        boolean contractDates = viewer.hasPermission("hr:contract-alert:read") ||
                viewer.hasPermission("hr:contract:read");
        boolean contractArchive = viewer.hasPermission("hr:contract:read");
        return new EmployeeArchiveDto(rs.getLong("id"), nullableLong(rs, "department_id"),
                rs.getString("real_name"), rs.getString("department_name"), rs.getString("duty"),
                rs.getString("role_code"), rs.getString("status"),
                contractDates ? rs.getObject("contract_end", LocalDate.class) : null,
                contractArchive ? rs.getString("contract_archive_status") : "RESTRICTED");
    }

    private Scope employeeScope(CurrentUser user, String alias) {
        if ("FOUNDER".equals(user.roleCode()) || user.hasPermission("hr:all:read")) {
            return new Scope("TRUE", List.of());
        }
        if ("DEPT_MANAGER".equals(user.roleCode())) {
            return new Scope(alias + ".department_id=?", List.of(user.departmentId()));
        }
        return new Scope(alias + ".id=?", List.of(user.id()));
    }

    private Long resolveUser(CreateEmployeeArchiveRequest request) {
        if (request.userId() != null) {
            if (!Boolean.TRUE.equals(jdbc.queryForObject(
                    "SELECT EXISTS(SELECT 1 FROM users WHERE id=? AND role_code<>'ADMIN')",
                    Boolean.class, request.userId()))) invalid("员工账号不存在");
            return request.userId();
        }
        String name = request.name() == null ? "" : request.name().trim();
        String department = request.department() == null ? "" : request.department().trim();
        if (name.isEmpty() || department.isEmpty()) invalid("请指定 userId，或提供唯一的姓名和部门");
        List<Long> ids = jdbc.queryForList(
                "SELECT u.id FROM users u JOIN departments d ON d.id=u.department_id " +
                        "WHERE u.real_name=? AND d.name=? AND u.role_code<>'ADMIN'",
                Long.class, name, department);
        if (ids.size() != 1) invalid("姓名和部门不能唯一定位现有员工账号");
        return ids.get(0);
    }

    private CurrentUser require(String permission) {
        CurrentUser user = context.require();
        if (!user.hasPermission(permission)) throw new BusinessException(ErrorCode.FORBIDDEN);
        return user;
    }

    private static Long nullableLong(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        return rs.getObject(column) == null ? null : rs.getLong(column);
    }

    private static void invalid(String message) {
        throw new BusinessException(ErrorCode.VALIDATION_FAILED, message);
    }
}
