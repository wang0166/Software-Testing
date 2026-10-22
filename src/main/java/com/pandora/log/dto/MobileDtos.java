package com.pandora.log.dto;

import java.time.LocalDate;
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

    public record LogRequest(String content) {
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
            OffsetDateTime updatedAt) {
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

    public record DispatchResultDto(Long taskId, int assigneeCount) {
    }

    public record DispatchedTaskDto(
            Long id,
            String name,
            String details,
            LocalDate startDate,
            LocalDate deadline,
            String urgency,
            int assigneeCount,
            int completedCount,
            int pendingReviewCount,
            OffsetDateTime createdAt) {
    }

    public record AssigneeDto(Long id, String realName) {
    }

    public record AssignmentDto(
            Long assignmentId,
            AssigneeDto assignee,
            String executionStatus,
            String reviewStatus,
            OffsetDateTime updatedAt) {
    }

    public record TaskDetailDto(
            Long id,
            Long senderId,
            String name,
            String details,
            LocalDate startDate,
            LocalDate deadline,
            String urgency,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            List<AssignmentDto> assignments) {
    }

    public record ReceivedTaskDto(
            Long assignmentId,
            Long taskId,
            String name,
            String details,
            LocalDate startDate,
            LocalDate deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            AssigneeDto sender,
            OffsetDateTime updatedAt) {
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
            LocalDate startDate,
            LocalDate deadline,
            String urgency,
            String executionStatus,
            String reviewStatus,
            AssigneeDto sender,
            List<ReviewHistoryDto> reviews) {
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
            LocalDate deadline,
            String urgency,
            String executionStatus,
            String reviewStatus) {
    }

    public record TaskMapDto(long total, int page, int size, List<TaskMapItemDto> items) {
    }
}
