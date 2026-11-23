package com.pandora.log.controller;

import java.util.List;

import org.springframework.web.bind.annotation.DeleteMapping;
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
import com.pandora.log.dto.MobileDtos.ApprovalRequest;
import com.pandora.log.dto.MobileDtos.AssignmentDetailDto;
import com.pandora.log.dto.MobileDtos.AssignmentStateDto;
import com.pandora.log.dto.MobileDtos.ChangeRequestDto;
import com.pandora.log.dto.MobileDtos.ChangeRequestViewDto;
import com.pandora.log.dto.MobileDtos.DispatchRequest;
import com.pandora.log.dto.MobileDtos.DispatchRequestDto;
import com.pandora.log.dto.MobileDtos.DispatchRequestResultDto;
import com.pandora.log.dto.MobileDtos.DispatchRequestViewDto;
import com.pandora.log.dto.MobileDtos.DispatchResultDto;
import com.pandora.log.dto.MobileDtos.DispatchedTaskDto;
import com.pandora.log.dto.MobileDtos.Items;
import com.pandora.log.dto.MobileDtos.ProgressRequest;
import com.pandora.log.dto.MobileDtos.RecipientDto;
import com.pandora.log.dto.MobileDtos.ReceivedTaskDto;
import com.pandora.log.dto.MobileDtos.ReviewRequest;
import com.pandora.log.dto.MobileDtos.SubordinateSummaryDto;
import com.pandora.log.dto.MobileDtos.TaskDetailDto;
import com.pandora.log.dto.MobileDtos.TaskProgressRequest;
import com.pandora.log.dto.MobileDtos.TaskProgressUpdateDto;
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

    @GetMapping("/recipients/all")
    public ApiResponse<PageResult<RecipientDto>> allRecipients(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.allRecipients(page, size));
    }

    @GetMapping("/subordinates/overview")
    public ApiResponse<PageResult<SubordinateSummaryDto>> subordinateOverview(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.subordinateOverview(page, size));
    }

    @PostMapping("/dispatch-requests")
    public ApiResponse<DispatchRequestResultDto> dispatchRequest(@RequestBody DispatchRequestDto request) {
        return ApiResponse.success(taskService.dispatchRequest(request));
    }

    @GetMapping("/dispatch-requests/mine")
    public ApiResponse<PageResult<DispatchRequestViewDto>> myDispatchRequests(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.myDispatchRequests(page, size));
    }

    @GetMapping("/dispatch-requests/reviewable")
    public ApiResponse<PageResult<DispatchRequestViewDto>> reviewableDispatchRequests(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.reviewableDispatchRequests(page, size));
    }

    @PutMapping("/dispatch-requests/{requestId}")
    public ApiResponse<DispatchRequestViewDto> updateDispatchRequest(@PathVariable Long requestId,
            @RequestBody DispatchRequestDto request) {
        return ApiResponse.success(taskService.updateDispatchRequest(requestId, request));
    }

    @DeleteMapping("/dispatch-requests/{requestId}")
    public ApiResponse<DispatchRequestViewDto> withdrawDispatchRequest(@PathVariable Long requestId) {
        return ApiResponse.success(taskService.withdrawDispatchRequest(requestId));
    }

    @PostMapping("/dispatch-requests/{requestId}/approve")
    public ApiResponse<DispatchRequestViewDto> approveDispatchRequest(@PathVariable Long requestId,
            @RequestBody(required = false) ApprovalRequest request) {
        return ApiResponse.success(taskService.approveDispatchRequest(requestId, request));
    }

    @PostMapping("/dispatch-requests/{requestId}/reject")
    public ApiResponse<DispatchRequestViewDto> rejectDispatchRequest(@PathVariable Long requestId,
            @RequestBody(required = false) ApprovalRequest request) {
        return ApiResponse.success(taskService.rejectDispatchRequest(requestId, request));
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

    @PostMapping("/assignments/{assignmentId}/progress-updates")
    public ApiResponse<TaskProgressUpdateDto> progressUpdate(@PathVariable Long assignmentId,
            @RequestBody TaskProgressRequest request) {
        return ApiResponse.success(taskService.progressUpdate(assignmentId, request));
    }

    @GetMapping("/assignments/{assignmentId}/progress-updates")
    public ApiResponse<Items<TaskProgressUpdateDto>> progressHistory(@PathVariable Long assignmentId) {
        return ApiResponse.success(new Items<>(taskService.progressHistory(assignmentId)));
    }

    @GetMapping("/subordinates/{userId}/assignments/{assignmentId}/progress-updates")
    public ApiResponse<Items<TaskProgressUpdateDto>> subordinateProgressHistory(
            @PathVariable Long userId, @PathVariable Long assignmentId) {
        return ApiResponse.success(new Items<>(
                taskService.subordinateProgressHistory(userId, assignmentId)));
    }

    @PostMapping("/{taskId}/change-requests")
    public ApiResponse<ChangeRequestViewDto> createChangeRequest(@PathVariable Long taskId,
            @RequestBody ChangeRequestDto request) {
        return ApiResponse.success(taskService.createChangeRequest(taskId, request));
    }

    @GetMapping("/change-requests/reviewable")
    public ApiResponse<PageResult<ChangeRequestViewDto>> reviewableChangeRequests(
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {
        return ApiResponse.success(taskService.reviewableChangeRequests(page, size));
    }

    @PostMapping("/change-requests/{requestId}/approve")
    public ApiResponse<ChangeRequestViewDto> approveChangeRequest(@PathVariable Long requestId,
            @RequestBody(required = false) ApprovalRequest request) {
        return ApiResponse.success(taskService.approveChangeRequest(requestId, request));
    }

    @PostMapping("/change-requests/{requestId}/reject")
    public ApiResponse<ChangeRequestViewDto> rejectChangeRequest(@PathVariable Long requestId,
            @RequestBody(required = false) ApprovalRequest request) {
        return ApiResponse.success(taskService.rejectChangeRequest(requestId, request));
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
