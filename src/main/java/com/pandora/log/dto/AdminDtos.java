package com.pandora.log.dto;

import java.util.List;

/**
 * Web 管理端（用户/组织/角色权限/配置/审计）的请求与响应模型。
 */
public final class AdminDtos {

    private AdminDtos() {
    }

    public record IdDto(Long id) {
    }

    public record UserDto(
            Long id,
            String username,
            String realName,
            String role,
            String status,
            Long departmentId,
            String departmentName,
            Long teamId,
            String teamName) {
    }

    public record UserCreateRequest(
            String username,
            String password,
            String realName,
            String role,
            Long departmentId,
            Long teamId) {
    }

    public record UserUpdateRequest(
            String realName,
            String role,
            Long departmentId,
            Long teamId) {
    }

    public record UserStatusRequest(Object status) {
    }

    public record PasswordResetRequest(String password) {
    }

    public record OrgUnitDto(Long id, String name, Long parentId) {
    }

    public record DepartmentCreateRequest(String name, Long companyId) {
    }

    public record TeamCreateRequest(String name, Long departmentId) {
    }

    public record RoleDto(String code, String name, List<String> permissions) {
    }

    public record PermissionDto(String code, String name, String module) {
    }

    public record RolePermissionsRequest(List<String> permissions) {
    }

    public record ConfigItemDto(String key, String value) {
    }

    public record ConfigUpdateRequest(String value) {
    }

    public record AuditDto(
            Long id,
            String actor,
            String action,
            String target,
            String time,
            String result) {
    }

    public record CompanyMatterRequest(String title, String content, Integer sortOrder) {
    }
}
