package com.pandora.log.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * 移动端业务接口的请求与响应模型，字段与 documents/后端接口文档.md 保持一致。
 */
public final class MobileDtos {

    private MobileDtos() {
    }

    public record Items<T>(List<T> items) {
    }

    public record LogRequest(String content, String logDate) {
    }

    public record LogCommentRequest(String content, Long parentId) {
    }

    public record WorkLogDto(
            Long id,
            Long authorId,
            String authorName,
            LocalDate logDate,
            String content,
            String status,
            boolean isImportant,
            OffsetDateTime submittedAt,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            String authorRole, Long departmentId, String departmentName, Long teamId, String teamName) {
    }

    public record LogCommentDto(
            Long id,
            Long logId,
            Long authorId,
            String authorName,
            String content,
            OffsetDateTime createdAt,
            Long parentId) {
    }

    public record OverviewDto(int expected, int submitted, int unsubmitted, double rate) {
    }

    public record TrendPointDto(LocalDate date, int count) {
    }

    public record TrendDto(List<TrendPointDto> days) {
    }

    public record UnsubmittedUserDto(Long id, String username, String realName) {
    }

    public record RecipientDto(
            Long id,
            String username,
            String realName,
            String role,
            Long departmentId,
            Long teamId,
            List<String> permissions) {
    }

    public record DispatchRequest(
            String name,
            String details,
            String startDate,
            String deadline,
            String urgency,
            List<Long> assigneeIds) {
    }

    public record DispatchRequestDto(
            String name,
            String details,
            String startDate,
            String deadline,
            String urgency,
            String taskType,
            List<Long> assigneeIds) {
    }

    // 任务变更申请：UPDATE 携带完整任务字段，DELETE 只需 action。
    public record ChangeRequestDto(
            String action,
            String name,
            String details,
            String startDate,
            String deadline,
            String urgency,
            String taskType,
            List<Long> assigneeIds) {
    }

    public record DispatchResultDto(Long taskId, int assigneeCount) {
    }

    public record DispatchRequestResultDto(Long id, Long requestId, Long taskId, String status, int assigneeCount) {
    }

    public record SubordinateTaskItemDto(
            Long assignmentId,
            Long taskId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            AssigneeDto sender,
            AssigneeDto assignee,
            OffsetDateTime updatedAt,
            String taskType,
            Integer progressPercent,
            String progressNote,
            OffsetDateTime progressUpdatedAt,
            int openIssueCount) {
    }

    public record SubordinateSummaryDto(
            Long userId,
            String username,
            String realName,
            String role,
            Long departmentId,
            String departmentName,
            Long teamId,
            String teamName,
            int total,
            int inProgress,
            int completed,
            int openIssueCount,
            List<SubordinateTaskItemDto> tasks) {
    }

    public record DispatchedTaskDto(
            Long id,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            int assigneeCount,
            int completedCount,
            int pendingReviewCount,
            OffsetDateTime createdAt,
            String taskType,
            boolean changePending) {
    }

    public record AssigneeDto(Long id, String realName) {
    }

    public record AssignmentDto(
            Long assignmentId,
            AssigneeDto assignee,
            String executionStatus,
            String reviewStatus,
            OffsetDateTime updatedAt,
            Integer progressPercent,
            String progressNote,
            OffsetDateTime progressUpdatedAt) {
    }

    public record TaskDetailDto(
            Long id,
            Long senderId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            String taskType,
            List<AssignmentDto> assignments) {
    }

    public record ReceivedTaskDto(
            Long assignmentId,
            Long taskId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            AssigneeDto sender,
            OffsetDateTime updatedAt,
            String taskType,
            Integer progressPercent,
            String progressNote,
            OffsetDateTime progressUpdatedAt,
            int openIssueCount) {
    }

    public record AssignmentStateDto(
            Long assignmentId,
            String executionStatus,
            String reviewStatus,
            OffsetDateTime updatedAt) {
    }

    public record ProgressRequest(String status) {
    }

    public record ReviewRequest(String result, String comment) {
    }

    public record ReviewHistoryDto(
            String action,
            Long actorId,
            String comment,
            OffsetDateTime createdAt) {
    }

    public record AssignmentDetailDto(
            Long assignmentId,
            Long taskId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            AssigneeDto sender,
            List<ReviewHistoryDto> reviews,
            String taskType,
            Integer progressPercent,
            String progressNote,
            OffsetDateTime progressUpdatedAt,
            int openIssueCount) {
    }

    public record TaskProgressRequest(String status, Integer progressPercent, String note) {
    }

    public record TaskProgressUpdateDto(
            Long id,
            Long assignmentId,
            String status,
            Integer progressPercent,
            String note,
            Long authorId,
            String authorName,
            OffsetDateTime createdAt) {
    }

    public record ApprovalRequest(String comment) {
    }

    public record DispatchRequestViewDto(
            Long id,
            Long requestId,
            Long taskId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String taskType,
            List<Long> assigneeIds,
            int assigneeCount,
            String status,
            Long requesterId,
            String requesterName,
            Long reviewerId,
            String reviewerName,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            String changeRequestStatus,
            boolean changePending) {
    }

    public record ChangeRequestViewDto(
            Long id,
            Long taskId,
            String action,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String taskType,
            List<Long> assigneeIds,
            int assigneeCount,
            String status,
            Long requesterId,
            String requesterName,
            Long reviewerId,
            String reviewerName,
            String reviewComment,
            OffsetDateTime reviewedAt,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt) {
    }

    public record PersonalTaskDto(
            Long id,
            Long ownerId,
            String name,
            String details,
            String status,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt) {
    }

    public record PersonalTaskRequest(String name, String details, String status) {
    }

    public record CompanyItemDto(
            Long id,
            String title,
            String content,
            int sortOrder,
            OffsetDateTime updatedAt) {
    }

    public record CalendarLogDto(Long logId, Long authorId, String status) {
    }

    public record CalendarTaskDto(
            Long taskId,
            Long assignmentId,
            String name,
            String executionStatus,
            String reviewStatus) {
    }

    public record CalendarDayDto(
            LocalDate date,
            int logCount,
            int taskCount,
            String mark,
            List<CalendarLogDto> logs,
            List<CalendarTaskDto> tasks) {
    }

    public record CalendarDto(List<CalendarDayDto> days) {
    }

    public record TaskMapItemDto(
            String source,
            Long taskId,
            Long assignmentId,
            Long personalTaskId,
            String name,
            String details,
            LocalDateTime startDate,
            LocalDateTime deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            String taskType,
            Integer progressPercent,
            String progressNote,
            OffsetDateTime progressUpdatedAt,
            int openIssueCount) {
    }

    public record DailyItemDto(
            Long id,
            LocalDate date,
            String title,
            String note,
            boolean completed,
            OffsetDateTime updatedAt) {
    }

    public record DailyItemRequest(
            LocalDate date,
            String title,
            String note,
            Boolean completed) {
    }

    public record TaskMapDto(long total, int page, int size, List<TaskMapItemDto> items) {
    }
}
