package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pandora.log.common.ApiResponse;
import com.pandora.log.common.PageResult;
import com.pandora.log.dto.MobileDtos.AssignmentDetailDto;
import com.pandora.log.dto.MobileDtos.AssignmentStateDto;
import com.pandora.log.dto.MobileDtos.DispatchRequest;
import com.pandora.log.dto.MobileDtos.DispatchResultDto;
import com.pandora.log.dto.MobileDtos.DispatchedTaskDto;
import com.pandora.log.dto.MobileDtos.Items;
import com.pandora.log.dto.MobileDtos.ProgressRequest;
import com.pandora.log.dto.MobileDtos.RecipientDto;
import com.pandora.log.dto.MobileDtos.ReceivedTaskDto;
import com.pandora.log.dto.MobileDtos.ReviewRequest;
import com.pandora.log.dto.MobileDtos.TaskDetailDto;
import com.pandora.log.service.TaskService;

@RestController
@RequestMapping("/api/tasks")
public class TaskController {

    private final TaskService taskService;

    public TaskController(TaskService taskService) {
        this.taskService = taskService;
    }

    @GetMapping("/recipients")
    public ApiResponse<Items<RecipientDto>> recipients() {
        List<RecipientDto> recipients = taskService.recipients();
        return ApiResponse.success(new Items<>(recipients));
    }

    @PostMapping
    public ApiResponse<DispatchResultDto> dispatch(@RequestBody DispatchRequest request) {
        return ApiResponse.success(taskService.dispatch(request));
    }

    @GetMapping("/dispatched")
    public ApiResponse<PageResult<DispatchedTaskDto>> dispatched(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.dispatched(page, size));
    }

    @GetMapping("/received")
    public ApiResponse<PageResult<ReceivedTaskDto>> received(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String reviewStatus,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.received(status, reviewStatus, page, size));
    }

    @GetMapping("/{taskId}")
    public ApiResponse<TaskDetailDto> detail(@PathVariable Long taskId) {
        return ApiResponse.success(taskService.detail(taskId));
    }

    @GetMapping("/assignments/{assignmentId}")
    public ApiResponse<AssignmentDetailDto> assignmentDetail(@PathVariable Long assignmentId) {
        return ApiResponse.success(taskService.assignmentDetail(assignmentId));
    }

    @PatchMapping("/assignments/{assignmentId}/progress")
    public ApiResponse<AssignmentStateDto> progress(@PathVariable Long assignmentId,
            @RequestBody ProgressRequest request) {
        return ApiResponse.success(taskService.progress(assignmentId,
                request == null ? null : request.status()));
    }

    @PostMapping("/assignments/{assignmentId}/review-invitations")
    public ApiResponse<AssignmentStateDto> inviteReview(@PathVariable Long assignmentId) {
        return ApiResponse.success(taskService.inviteReview(assignmentId));
    }

    @PostMapping("/assignments/{assignmentId}/review")
    public ApiResponse<AssignmentStateDto> review(@PathVariable Long assignmentId,
            @RequestBody ReviewRequest request) {
        return ApiResponse.success(taskService.review(assignmentId,
                request == null ? null : request.result(),
                request == null ? null : request.comment()));
    }
}
