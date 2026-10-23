package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.dto.AdminDtos.PermissionDto;
import com.pandora.log.dto.AdminDtos.RoleDto;
import com.pandora.log.dto.AdminDtos.RolePermissionsRequest;
import com.pandora.log.service.RolePermissionService;

@RestController
@RequestMapping("/api")
public class RoleController {

    private final RolePermissionService rolePermissionService;

    public RoleController(RolePermissionService rolePermissionService) {
        this.rolePermissionService = rolePermissionService;
    }

    @GetMapping("/roles")
    public ApiResponse<List<RoleDto>> roles() {
        return ApiResponse.success(rolePermissionService.roles());
    }

    @GetMapping("/permissions")
    public ApiResponse<List<PermissionDto>> permissions() {
        return ApiResponse.success(rolePermissionService.permissions());
    }

    @PutMapping("/roles/{code}/permissions")
    public ApiResponse<Void> replacePermissions(@PathVariable String code,
            @RequestBody RolePermissionsRequest request) {
        rolePermissionService.replacePermissions(code, request == null ? null : request.permissions());
        return ApiResponse.success();
    }
}
