package com.pandora.log.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.AdminDtos.IdDto;
import com.pandora.log.dto.AdminDtos.PasswordResetRequest;
import com.pandora.log.dto.AdminDtos.UserCreateRequest;
import com.pandora.log.dto.AdminDtos.UserDto;
import com.pandora.log.dto.AdminDtos.UserStatusRequest;
import com.pandora.log.dto.AdminDtos.UserUpdateRequest;
import com.pandora.log.service.UserService;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ApiResponse<PageResult<UserDto>> list(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String role,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long teamId,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(userService.list(keyword, role, status, departmentId, teamId, page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<UserDto> get(@PathVariable String id) {
        return ApiResponse.success(userService.get(id));
    }

    @PostMapping
    public ApiResponse<IdDto> create(@RequestBody UserCreateRequest request) {
        return ApiResponse.success(new IdDto(userService.create(request)));
    }

    @PutMapping("/{id}")
    public ApiResponse<UserDto> update(@PathVariable String id, @RequestBody UserUpdateRequest request) {
        return ApiResponse.success(userService.update(id, request));
    }

    @PatchMapping("/{id}/status")
    public ApiResponse<UserDto> updateStatus(@PathVariable String id, @RequestBody UserStatusRequest request) {
        return ApiResponse.success(userService.updateStatus(id, request == null ? null : request.status()));
    }

    @PutMapping("/{id}/password")
    public ApiResponse<Void> resetPassword(@PathVariable String id, @RequestBody PasswordResetRequest request) {
        userService.resetPassword(id, request == null ? null : request.password());
        return ApiResponse.success();
    }
}
