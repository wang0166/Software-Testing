package com.pandora.log.controller;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.PasswordDtos.*;
import com.pandora.log.service.PasswordRequestService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class PasswordController {
    private final PasswordRequestService service;
    public PasswordController(PasswordRequestService service) { this.service=service; }
    @PostMapping("/auth/password-reset-requests")
    public ApiResponse<Accepted> requestReset(@Valid @RequestBody ResetRequest r, HttpServletRequest request) {
        return ApiResponse.success(service.requestReset(r.username(),request.getRemoteAddr()));
    }
    @PostMapping("/auth/password-reset")
    public ApiResponse<Void> reset(@Valid @RequestBody ResetCompletion r,HttpServletRequest request) {
        service.completeReset(r.token(),r.newPassword(),request.getRemoteAddr()); return ApiResponse.success();
    }
    @PostMapping("/account/password-change-requests")
    public ApiResponse<StatusDto> requestChange() { return ApiResponse.success(service.requestChange()); }
    @GetMapping("/account/password-change-requests/me")
    public ApiResponse<StatusDto> status() { return ApiResponse.success(service.changeStatus()); }
    @PostMapping("/account/password-change")
    public ApiResponse<Void> change(@Valid @RequestBody ChangeRequest r) {
        service.completeChange(r.newPassword()); return ApiResponse.success();
    }
    @GetMapping("/password-requests")
    public ApiResponse<PageResult<RequestDto>> list(@RequestParam(required=false) String status,
            @RequestParam(required=false) String kind,@RequestParam(required=false) Integer page,
            @RequestParam(required=false) Integer size) { return ApiResponse.success(service.list(status,kind,page,size)); }
    @PostMapping("/password-requests/{id}/review")
    public ApiResponse<ReviewDto> review(@PathVariable Long id,@Valid @RequestBody ReviewRequest r,HttpServletResponse response) {
        response.setHeader("Cache-Control","no-store"); response.setHeader("Pragma","no-cache");
        return ApiResponse.success(service.review(id,r));
    }
}
