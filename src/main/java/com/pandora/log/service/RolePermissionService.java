package com.pandora.log.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pandora.log.common.BusinessException;
import com.pandora.log.common.CurrentUser;
import com.pandora.log.common.ErrorCode;
import com.pandora.log.dto.AdminDtos.PermissionDto;
import com.pandora.log.dto.AdminDtos.RoleDto;
import com.pandora.log.security.CurrentUserContext;

@Service
public class RolePermissionService {

    private final JdbcTemplate jdbcTemplate;
    private final CurrentUserContext currentUserContext;
    private final AuditService auditService;

    public RolePermissionService(JdbcTemplate jdbcTemplate,
            CurrentUserContext currentUserContext,
            AuditService auditService) {
        this.jdbcTemplate = jdbcTemplate;
        this.currentUserContext = currentUserContext;
        this.auditService = auditService;
    }

    public List<RoleDto> roles() {
        requireManage();
        Map<String, String> roleNames = new LinkedHashMap<>();
        for (Map<String, Object> row : jdbcTemplate.queryForList("SELECT code, name FROM roles ORDER BY code")) {
            roleNames.put((String) row.get("code"), (String) row.get("name"));
        }
        Map<String, List<String>> rolePermissions = new LinkedHashMap<>();
        for (String code : roleNames.keySet()) {
            rolePermissions.put(code, new ArrayList<>());
        }
        for (Map<String, Object> row : jdbcTemplate.queryForList(
                "SELECT role_code, permission_code FROM role_permissions ORDER BY role_code, permission_code")) {
            List<String> permissions = rolePermissions.get((String) row.get("role_code"));
            if (permissions != null) {
                permissions.add((String) row.get("permission_code"));
            }
        }
        List<RoleDto> result = new ArrayList<>();
        roleNames.forEach((code, name) -> result.add(new RoleDto(code, name, rolePermissions.get(code))));
        return result;
    }

    public List<PermissionDto> permissions() {
        requireManage();
        return jdbcTemplate.query("SELECT code, name, module FROM permissions ORDER BY module, code",
                (rs, index) -> new PermissionDto(rs.getString("code"), rs.getString("name"), rs.getString("module")));
    }

    @Transactional
    public void replacePermissions(String roleCode, List<String> permissions) {
        requireManage();
        if (roleCode == null || roleCode.isBlank()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "角色不能为空");
        }
        String code = roleCode.trim().toUpperCase();
        Long exists = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM roles WHERE code = ?", Long.class, code);
        if (exists == null || exists == 0) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "角色不存在");
        }
        List<String> target = permissions == null ? List.of() : permissions.stream()
                .filter(item -> item != null && !item.isBlank())
                .map(String::trim)
                .distinct()
                .toList();

        jdbcTemplate.update("DELETE FROM role_permissions WHERE role_code = ?", code);
        try {
            for (String permission : target) {
                insertPermission(code, permission);
            }
            // 管理员必须保留管理端权限，避免把自己锁在门外
            if ("ADMIN".equals(code)) {
                for (String required : List.of("user:manage", "org:manage", "role:manage",
                        "config:manage", "audit:read")) {
                    insertPermission(code, required);
                }
            }
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "存在不合法的权限码");
        }
        auditService.record("修改角色权限", "ROLE", code, String.join(",", target), "SUCCESS");
    }

    private void insertPermission(String roleCode, String permissionCode) {
        jdbcTemplate.update("INSERT INTO role_permissions (role_code, permission_code) VALUES (?, ?) "
                + "ON CONFLICT DO NOTHING", roleCode, permissionCode);
    }

    private void requireManage() {
        CurrentUser currentUser = currentUserContext.require();
        if (!currentUser.hasPermission("role:manage")) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }
}
