package com.pandora.log.dto;

import java.util.List;

import com.pandora.log.common.CurrentUser;

public record CurrentUserResponse(
        Long id,
        String username,
        String realName,
        String role,
        Long departmentId,
        Long teamId,
        List<String> permissions) {

    public static CurrentUserResponse from(CurrentUser currentUser) {
        return new CurrentUserResponse(
                currentUser.id(),
                currentUser.username(),
                currentUser.realName(),
                currentUser.roleCode(),
                currentUser.departmentId(),
                currentUser.teamId(),
                currentUser.permissions() == null ? List.of() : List.copyOf(currentUser.permissions()));
    }
}
