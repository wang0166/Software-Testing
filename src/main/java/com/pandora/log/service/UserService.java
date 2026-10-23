package com.pandora.log.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

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
import com.pandora.log.dto.AdminDtos.UserCreateRequest;
import com.pandora.log.dto.AdminDtos.UserDto;
import com.pandora.log.dto.AdminDtos.UserUpdateRequest;
import com.pandora.log.security.CurrentUserContext;
import com.pandora.log.security.PasswordService;

@Service
public class UserService {

    private static final Set<String> ROLES = Set.of("EMPLOYEE", "TEAM_LEADER", "DEPT_MANAGER", "FOUNDER", "ADMIN");

    private static final String USER_SELECT = "SELECT u.id, u.username, u.real_name, u.role_code, u.status, "
            + "u.department_id, d.name AS department_name, u.team_id, t.name AS team_name "
            + "FROM users u LEFT JOIN departments d ON d.id = u.department_id "
            + "LEFT JOIN teams t ON t.id = u.team_id ";

    private static final RowMapper<UserDto> USER_MAPPER = (rs, index) -> new UserDto(
            rs.getLong("id"),
            rs.getString("username"),
            rs.getString("real_name"),
            rs.getString("role_code"),
            rs.getString("status"),
            rs.getObject("department_id", Long.class),
            rs.getString("department_name"),
            rs.getObject("team_id", Long.class),
            rs.getString("team_name"));

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final PasswordService passwordService;
    private final AuditService auditService;

    public UserService(JdbcTemplate jdbcTemplate,
            CurrentUserContext currentUserContext,
            PasswordService passwordService,
            AuditService auditService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.passwordService = passwordService;
        this.auditService = auditService;
    }

    public PageResult<UserDto> list(String keyword, String role, String status,
            Long departmentId, Long teamId, Integer page, Integer size) {
        requireManage();
        PageQuery pageQuery = PageQuery.of(page, size);

        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            where.append(" AND (u.username ILIKE ? OR u.real_name ILIKE ?)");
            String like = "%" + keyword.trim() + "%";
            args.add(like);
            args.add(like);
        }
        if (role != null && !role.isBlank()) {
            where.append(" AND u.role_code = ?");
            args.add(normalizeRole(role));
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND u.status = ?");
            args.add(normalizeStatus(status));
        }
        if (departmentId != null) {
            where.append(" AND u.department_id = ?");
            args.add(departmentId);
        }
        if (teamId != null) {
            where.append(" AND u.team_id = ?");
            args.add(teamId);
        }

        Long total = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users u" + where, Long.class, args.toArray());
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(pageQuery.size());
        pageArgs.add(pageQuery.offset());
        List<UserDto> items = jdbcTemplate.query(
                USER_SELECT + where + " ORDER BY u.id LIMIT ? OFFSET ?", USER_MAPPER, pageArgs.toArray());
        return new PageResult<>(total == null ? 0 : total, pageQuery.page(), pageQuery.size(), items);
    }

    public UserDto get(String idOrUsername) {
        requireManage();
        return requireUser(idOrUsername);
    }

    @Transactional
    public Long create(UserCreateRequest request) {
        requireManage();
        if (request == null) {
            throw validation("请求体不能为空");
        }
        String username = request.username() == null ? "" : request.username().trim().toLowerCase();
        if (!username.matches("^[a-z0-9_]{3,20}$")) {
            throw validation("账号需为 3~20 位英文小写、数字或下划线");
        }
        String password = request.password() == null ? "" : request.password();
        if (password.length() < 6) {
            throw validation("密码至少 6 位");
        }
        String realName = request.realName() == null ? "" : request.realName().trim();
        if (realName.isEmpty()) {
            throw validation("姓名不能为空");
        }
        String role = normalizeRole(request.role());

        Long departmentId = request.departmentId();
        Long teamId = request.teamId();
        OrgRef org = validateOrg(role, departmentId, teamId, null);

        if (existsByUsername(username)) {
            throw new BusinessException(ErrorCode.USERNAME_EXISTS);
        }

        Long userId;
        try {
            userId = jdbcTemplate.queryForObject(
                    "INSERT INTO users (username, password_hash, real_name, role_code, department_id, team_id, "
                            + "status, failed_attempts) VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE', 0) RETURNING id",
                    Long.class, username, passwordService.encode(password), realName, role,
                    org.departmentId(), org.teamId());
        } catch (DuplicateKeyException exception) {
            throw new BusinessException(ErrorCode.USERNAME_EXISTS);
        }

        assignOwner(role, org.departmentId(), org.teamId(), userId);
        auditService.record("创建用户", "USER", String.valueOf(userId), username + " / " + realName, "SUCCESS");
        return userId;
    }

    @Transactional
    public UserDto update(String idOrUsername, UserUpdateRequest request) {
        requireManage();
        if (request == null) {
            throw validation("请求体不能为空");
        }
        UserDto current = requireUser(idOrUsername);
        String realName = request.realName() == null ? current.realName() : request.realName().trim();
        if (realName == null || realName.isEmpty()) {
            throw validation("姓名不能为空");
        }

        String role = current.role();
        Long departmentId = current.departmentId();
        Long teamId = current.teamId();
        if (request.role() != null && !request.role().isBlank()) {
            role = normalizeRole(request.role());
            departmentId = request.departmentId();
            teamId = request.teamId();
        } else if (request.departmentId() != null || request.teamId() != null) {
            departmentId = request.departmentId();
            teamId = request.teamId();
        }

        OrgRef org = validateOrg(role, departmentId, teamId, current.id());

        clearOwner(current.id());
        jdbcTemplate.update(
                "UPDATE users SET real_name = ?, role_code = ?, department_id = ?, team_id = ?, updated_at = now() "
                        + "WHERE id = ?",
                realName, role, org.departmentId(), org.teamId(), current.id());
        assignOwner(role, org.departmentId(), org.teamId(), current.id());

        auditService.record("编辑用户", "USER", String.valueOf(current.id()),
                current.username() + " / " + realName, "SUCCESS");
        return requireUser(String.valueOf(current.id()));
    }

    public UserDto updateStatus(String idOrUsername, Object rawStatus) {
        requireManage();
        UserDto current = requireUser(idOrUsername);
        String status = normalizeStatus(rawStatus);

        jdbcTemplate.update("UPDATE users SET status = ?, failed_attempts = 0, locked_until = NULL, "
                + "updated_at = now() WHERE id = ?", status, current.id());
        auditService.record("ACTIVE".equals(status) ? "启用账号" : "停用账号", "USER",
                String.valueOf(current.id()), current.username() + " / " + current.realName(), "SUCCESS");
        return requireUser(String.valueOf(current.id()));
    }

    public void resetPassword(String idOrUsername, String password) {
        requireManage();
        if (password == null || password.length() < 6) {
            throw validation("密码至少 6 位");
        }
        UserDto current = requireUser(idOrUsername);
        jdbcTemplate.update("UPDATE users SET password_hash = ?, failed_attempts = 0, locked_until = NULL, "
                + "updated_at = now() WHERE id = ?", passwordService.encode(password), current.id());
        auditService.record("重置密码", "USER", String.valueOf(current.id()), current.username(), "SUCCESS");
    }

    private void requireManage() {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("user:manage")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }

    private UserDto requireUser(String idOrUsername) {
        List<UserDto> rows;
        if (idOrUsername != null && idOrUsername.matches("\\d+")) {
            rows = jdbcTemplate.query(USER_SELECT + " WHERE u.id = ?", USER_MAPPER, Long.valueOf(idOrUsername));
        } else {
            rows = jdbcTemplate.query(USER_SELECT + " WHERE u.username = ?", USER_MAPPER, idOrUsername);
        }
        if (rows.isEmpty()) {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }
        return rows.get(0);
    }

    private boolean existsByUsername(String username) {
        Long count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users WHERE username = ?", Long.class, username);
        return count != null && count > 0;
    }

    private static String normalizeRole(String role) {
        if (role == null || role.isBlank()) {
            throw validation("角色不能为空");
        }
        String value = role.trim().toUpperCase();
        if (!ROLES.contains(value)) {
            throw validation("角色不合法");
        }
        return value;
    }

    private static String normalizeStatus(Object rawStatus) {
        if (rawStatus instanceof Number number) {
            return number.intValue() == 1 ? "ACTIVE" : "DISABLED";
        }
        if (rawStatus instanceof Boolean enabled) {
            return enabled ? "ACTIVE" : "DISABLED";
        }
        String value = rawStatus == null ? "" : rawStatus.toString().trim().toUpperCase();
        return switch (value) {
            case "1", "ACTIVE", "启用", "ENABLED" -> "ACTIVE";
            case "0", "DISABLED", "停用", "LOCKED" -> "DISABLED";
            default -> throw validation("状态不合法");
        };
    }

    /** 按文档第 3 节校验角色与组织归属，返回落库使用的部门/团队。 */
    private OrgRef validateOrg(String role, Long departmentId, Long teamId, Long selfId) {
        switch (role) {
            case "EMPLOYEE", "TEAM_LEADER" -> {
                if (departmentId == null || teamId == null) {
                    throw validation("该角色必须指定部门和团队");
                }
                requireDepartment(departmentId);
                Long teamDepartmentId = teamDepartment(teamId);
                if (!departmentId.equals(teamDepartmentId)) {
                    throw validation("团队不属于所选部门");
                }
                if ("TEAM_LEADER".equals(role)) {
                    assertNoOtherOwner("SELECT leader_id FROM teams WHERE id = ?", teamId, selfId, "该团队已有团队长");
                }
                return new OrgRef(departmentId, teamId);
            }
            case "DEPT_MANAGER" -> {
                if (departmentId == null) {
                    throw validation("部门老总必须指定部门");
                }
                requireDepartment(departmentId);
                assertNoOtherOwner("SELECT manager_id FROM departments WHERE id = ?", departmentId, selfId,
                        "该部门已有部门老总");
                return new OrgRef(departmentId, null);
            }
            case "FOUNDER" -> {
                Long companyId = firstCompanyId();
                assertNoOtherOwner("SELECT founder_id FROM companies WHERE id = ?", companyId, selfId,
                        "该公司已有创始人");
                return new OrgRef(null, null);
            }
            default -> {
                return new OrgRef(null, null);
            }
        }
    }

    private void requireDepartment(Long departmentId) {
        Long count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM departments WHERE id = ?", Long.class,
                departmentId);
        if (count == null || count == 0) {
            throw validation("部门不存在");
        }
    }

    private Long teamDepartment(Long teamId) {
        List<Long> rows = jdbcTemplate.queryForList("SELECT department_id FROM teams WHERE id = ?", Long.class,
                teamId);
        if (rows.isEmpty()) {
            throw validation("团队不存在");
        }
        return rows.get(0);
    }

    private Long firstCompanyId() {
        List<Long> rows = jdbcTemplate.queryForList("SELECT id FROM companies ORDER BY id LIMIT 1", Long.class);
        if (rows.isEmpty()) {
            throw validation("请先创建公司");
        }
        return rows.get(0);
    }

    private void assertNoOtherOwner(String sql, Long id, Long selfId, String message) {
        List<Long> rows = jdbcTemplate.queryForList(sql, Long.class, id);
        if (!rows.isEmpty() && rows.get(0) != null && !rows.get(0).equals(selfId)) {
            throw new BusinessException(ErrorCode.ORG_OWNER_EXISTS, message);
        }
    }

    private void clearOwner(Long userId) {
        jdbcTemplate.update("UPDATE companies SET founder_id = NULL WHERE founder_id = ?", userId);
        jdbcTemplate.update("UPDATE departments SET manager_id = NULL WHERE manager_id = ?", userId);
        jdbcTemplate.update("UPDATE teams SET leader_id = NULL WHERE leader_id = ?", userId);
    }

    private void assignOwner(String role, Long departmentId, Long teamId, Long userId) {
        switch (role) {
            case "FOUNDER" -> jdbcTemplate.update("UPDATE companies SET founder_id = ? WHERE id = ?",
                    userId, firstCompanyId());
            case "DEPT_MANAGER" -> jdbcTemplate.update("UPDATE departments SET manager_id = ? WHERE id = ?",
                    userId, departmentId);
            case "TEAM_LEADER" -> jdbcTemplate.update("UPDATE teams SET leader_id = ? WHERE id = ?",
                    userId, teamId);
            default -> {
                // 员工与管理员不担任组织负责人
            }
        }
    }

    private static BusinessException validation(String message) {
        return new BusinessException(ErrorCode.VALIDATION_FAILED, message);
    }

    private record OrgRef(Long departmentId, Long teamId) {
    }
}
