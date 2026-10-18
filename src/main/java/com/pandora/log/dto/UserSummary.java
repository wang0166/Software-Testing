package com.pandora.log.dto;

import com.pandora.log.entity.User;

public record UserSummary(
        Long id,
        String username,
        String realName,
        String role,
        Long departmentId,
        Long teamId) {

    public static UserSummary from(User user) {
        return new UserSummary(
                user.getId(),
                user.getUsername(),
                user.getRealName(),
                user.getRoleCode(),
                user.getDepartmentId(),
                user.getTeamId());
    }
}
