package com.pandora.log.common;

import java.util.Set;

public record CurrentUser(
        Long id,
        String username,
        String realName,
        String roleCode,
        Long departmentId,
        Long teamId,
        Set<String> permissions) {

    public boolean hasPermission(String permissionCode) {
        return permissions != null && permissions.contains(permissionCode);
    }
}
