package com.pandora.log.dto;

import java.util.List;

import com.pandora.log.entity.User;

public record UserSummary(
        Long id,
        String username,
        String realName,
        String role,
        Long departmentId,
        Long teamId,
        List<String> permissions) {

    public static UserSummary from(User user, List<String> permissions) {
        return new UserSummary(
                user.getId(),
                user.getUsername(),
                user.getRealName(),
                user.getRoleCode(),
                user.getDepartmentId(),
                user.getTeamId(),
                permissions == null ? List.of() : List.copyOf(permissions));
    }
}
