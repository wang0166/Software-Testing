package com.pandora.log.service;

import java.nio.charset.StandardCharsets;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.pandora.log.common.*;
import com.pandora.log.dto.AdminDtos.*;
import com.pandora.log.security.PasswordService;

@Service
public class AdminUserService {
    private static final Set<String> ROLES = Set.of("ADMIN", "FOUNDER", "DEPT_MANAGER", "TEAM_LEADER", "EMPLOYEE");
    private static final String SELECT = "SELECT u.id, u.username, u.real_name, u.role_code, u.status, "
            + "u.department_id, u.team_id, d.name AS department_name, t.name AS team_name, u.phone, u.gender, u.id_number "
            + "FROM users u LEFT JOIN departments d ON d.id=u.department_id LEFT JOIN teams t ON t.id=u.team_id";
    private static final RowMapper<UserDto> MAPPER = (rs, n) -> new UserDto(rs.getLong("id"),
            rs.getString("username"), rs.getString("real_name"), rs.getString("role_code"), rs.getString("status"),
            rs.getObject("department_id", Long.class), rs.getObject("team_id", Long.class),
            rs.getString("department_name"), rs.getString("team_name"), rs.getString("phone"),
            rs.getString("gender"), rs.getString("id_number"));
    private final JdbcTemplate jdbc;
    private final AdminSupport support;
    private final PasswordService passwords;

    public AdminUserService(JdbcTemplate jdbc, AdminSupport support, PasswordService passwords) {
        this.jdbc = jdbc; this.support = support; this.passwords = passwords;
    }

    public PageResult<UserDto> list(String keyword, String role, String status, Long departmentId, Long teamId,
            Integer page, Integer size) {
        support.require("user:manage");
        PageQuery pq = PageQuery.of(page, size);
        StringBuilder where = new StringBuilder(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            where.append(" AND (position(lower(?) in lower(u.username)) > 0 OR position(lower(?) in lower(u.real_name)) > 0)");
            args.add(keyword.trim()); args.add(keyword.trim());
        }
        if (role != null && !role.isBlank()) {
            validateRole(role); where.append(" AND u.role_code=?"); args.add(role);
        }
        if (status != null && !status.isBlank()) {
            String value = switch (status) { case "1" -> "ACTIVE"; case "0" -> "DISABLED"; default -> status; };
            if (!Set.of("ACTIVE", "DISABLED", "LOCKED").contains(value)) AdminSupport.invalid("status 非法");
            where.append(" AND u.status=?"); args.add(value);
        }
        if (departmentId != null) { where.append(" AND u.department_id=?"); args.add(departmentId); }
        if (teamId != null) { where.append(" AND u.team_id=?"); args.add(teamId); }
        Long total = jdbc.queryForObject("SELECT count(*) FROM users u" + where, Long.class, args.toArray());
        args.add(pq.size()); args.add(pq.offset());
        return new PageResult<>(total, pq.page(), pq.size(), jdbc.query(SELECT + where
                + " ORDER BY u.id LIMIT ? OFFSET ?", MAPPER, args.toArray()));
    }

    public UserDto get(Long id) {
        support.require("user:manage");
        return find(id);
    }

    private UserDto find(Long id) {
        return jdbc.query(SELECT + " WHERE u.id=?", MAPPER, id).stream().findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }

    @Transactional
    public IdDto create(CreateUserRequest request) {
        support.require("user:manage"); support.lock();
        validatePassword(request.password());
        if (support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE username=?)", request.username())) {
            throw new BusinessException(ErrorCode.USERNAME_EXISTS);
        }
        validateAssignment(request.role(), request.departmentId(), request.teamId(), -1L);
        Long id = jdbc.queryForObject("INSERT INTO users(username,password_hash,real_name,role_code,department_id,team_id,"
                + "phone,gender,id_number) VALUES (?,?,?,?,?,?,?,?,?) RETURNING id", Long.class,
                request.username(), passwords.encode(request.password()), request.realName().trim(), request.role(),
                request.departmentId(), request.teamId(), request.phone(), blankToNull(request.gender()), blankToNull(request.idNumber()));
        syncOwner(id, request.role(), request.departmentId(), request.teamId());
        support.audit("创建用户", "USER", id);
        return new IdDto(id);
    }

    @Transactional
    public void update(Long id, UpdateUserRequest request) {
        support.require("user:manage"); support.lock();
        UserDto old = find(id);
        protectLastAdmin(old, request.role(), old.status());
        validateAssignment(request.role(), request.departmentId(), request.teamId(), id);
        jdbc.update("UPDATE users SET real_name=?, role_code=?, department_id=?, team_id=?, "
                + "auth_version=auth_version+1, updated_at=now() WHERE id=?", request.realName().trim(), request.role(),
                request.departmentId(), request.teamId(), id);
        syncOwner(id, request.role(), request.departmentId(), request.teamId());
        revokeRefresh(id);
        support.audit("编辑用户", "USER", id);
    }

    @Transactional
    public void status(Long id, UserStatusRequest request) {
        support.require("user:manage"); support.lock();
        UserDto old = find(id);
        String status = request.status() == 1 ? "ACTIVE" : "DISABLED";
        protectLastAdmin(old, old.role(), status);
        jdbc.update("UPDATE users SET status=?, failed_attempts=0, locked_until=NULL, "
                + "auth_version=auth_version+1, updated_at=now() WHERE id=?", status, id);
        revokeRefresh(id);
        support.audit(request.status() == 1 ? "启用账号" : "停用账号", "USER", id);
    }

    @Transactional
    public void password(Long id, PasswordRequest request) {
        support.require("user:manage"); support.lock(); find(id);
        validatePassword(request.password());
        jdbc.update("UPDATE users SET password_hash=?, failed_attempts=0, locked_until=NULL, "
                + "auth_version=auth_version+1, updated_at=now() WHERE id=?", passwords.encode(request.password()), id);
        revokeRefresh(id);
        support.audit("重置密码", "USER", id);
    }

    private void revokeRefresh(Long id) {
        jdbc.update("UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=? AND revoked_at IS NULL", id);
    }

    private void protectLastAdmin(UserDto old, String role, String status) {
        if (old.role().equals("ADMIN") && old.status().equals("ACTIVE")
                && (!role.equals("ADMIN") || !status.equals("ACTIVE"))
                && !support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE role_code='ADMIN' AND status='ACTIVE' AND id<>?)", old.id())) {
            throw new BusinessException(ErrorCode.LAST_ADMIN);
        }
    }

    private void validateAssignment(String role, Long department, Long team, Long id) {
        validateRole(role);
        if (Set.of("ADMIN", "FOUNDER").contains(role)) {
            if (department != null || team != null) AdminSupport.invalid("该角色不能归属部门或团队");
        } else {
            if (department == null || !support.exists("SELECT EXISTS(SELECT 1 FROM departments WHERE id=?)", department)) {
                AdminSupport.invalid("请选择有效部门");
            }
            if (role.equals("DEPT_MANAGER")) {
                if (team != null) AdminSupport.invalid("部门负责人不能归属团队");
            } else if (team == null || !support.exists("SELECT EXISTS(SELECT 1 FROM teams WHERE id=? AND department_id=?)", team, department)) {
                AdminSupport.invalid("团队必须属于所选部门");
            }
        }
        if (role.equals("FOUNDER") || role.equals("DEPT_MANAGER") || role.equals("TEAM_LEADER")) {
            String condition = role.equals("FOUNDER") ? "" : role.equals("DEPT_MANAGER") ? " AND department_id=?" : " AND team_id=?";
            List<Object> args = new ArrayList<>(List.of(role, id));
            if (!condition.isEmpty()) args.add(role.equals("DEPT_MANAGER") ? department : team);
            if (support.exists("SELECT EXISTS(SELECT 1 FROM users WHERE role_code=? AND id<>?" + condition + ")", args.toArray())) {
                throw new BusinessException(ErrorCode.OWNER_EXISTS);
            }
        }
        if (role.equals("FOUNDER") && jdbc.queryForObject("SELECT count(*) FROM companies", Long.class) != 1) {
            AdminSupport.invalid("公司信息必须唯一明确，才能指定创始人");
        }
    }

    private void syncOwner(Long id, String role, Long department, Long team) {
        jdbc.update("UPDATE companies SET founder_id=NULL WHERE founder_id=?", id);
        jdbc.update("UPDATE departments SET manager_id=NULL WHERE manager_id=?", id);
        jdbc.update("UPDATE teams SET leader_id=NULL WHERE leader_id=?", id);
        if (role.equals("FOUNDER")) jdbc.update("UPDATE companies SET founder_id=?", id);
        if (role.equals("DEPT_MANAGER")) jdbc.update("UPDATE departments SET manager_id=? WHERE id=?", id, department);
        if (role.equals("TEAM_LEADER")) jdbc.update("UPDATE teams SET leader_id=? WHERE id=?", id, team);
    }

    private static void validateRole(String role) {
        if (!ROLES.contains(role)) AdminSupport.invalid("role 非法");
    }
    private static void validatePassword(String password) {
        if (password == null || password.isBlank() || password.length() < 6
                || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            AdminSupport.invalid("密码至少 6 位且不能全为空格，UTF-8 编码不得超过 72 字节");
        }
    }
    private static String blankToNull(String value) { return value == null || value.isBlank() ? null : value; }
}
