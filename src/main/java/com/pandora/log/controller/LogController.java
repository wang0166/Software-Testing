package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.LogCommentDto;
import com.pandora.log.dto.MobileDtos.LogCommentRequest;
import com.pandora.log.dto.MobileDtos.LogRequest;
import com.pandora.log.dto.MobileDtos.WorkLogDto;
import com.pandora.log.service.LogService;

@RestController
@RequestMapping("/api/logs")
public class LogController {

    private final LogService logService;

    public LogController(LogService logService) {
        this.logService = logService;
    }

    @GetMapping
    public ApiResponse<PageResult<WorkLogDto>> list(
            @RequestParam(required = false) String date,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long authorId,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(logService.list(date, status, authorId, page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<WorkLogDto> get(@PathVariable Long id) {
        return ApiResponse.success(logService.get(id));
    }

    @PostMapping
    public ApiResponse<WorkLogDto> create(@RequestBody LogRequest request) {
        return ApiResponse.success(logService.create(request == null ? null : request.content()));
    }

    @PutMapping("/{id}")
    public ApiResponse<WorkLogDto> update(@PathVariable Long id, @RequestBody LogRequest request) {
        return ApiResponse.success(logService.update(id, request == null ? null : request.content()));
    }

    @PostMapping("/{id}/submit")
    public ApiResponse<WorkLogDto> submit(@PathVariable Long id) {
        return ApiResponse.success(logService.submit(id));
    }

    @GetMapping("/{id}/comments")
    public ApiResponse<List<LogCommentDto>> comments(@PathVariable Long id) {
        return ApiResponse.success(logService.comments(id));
    }

    @PostMapping("/{id}/comments")
    public ApiResponse<LogCommentDto> addComment(@PathVariable Long id,
            @RequestBody LogCommentRequest request) {
        return ApiResponse.success(logService.addComment(id,
                request == null ? null : request.content(),
                request == null ? null : request.parentId()));
    }
}
