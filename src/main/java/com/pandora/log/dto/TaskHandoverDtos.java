package com.pandora.log.dto;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;

public final class TaskHandoverDtos {
    private TaskHandoverDtos() {
    }

    public record HandoverDto(
            String id, Long originalUserId, Long originalAssignmentId,
            String originalUserName, String taskName, String taskDetails,
            String executionStatus, String status, String taskType,
            String urgency, String progressNote, int progressPercent,
            LocalDateTime deadline, OffsetDateTime completedAt, String note,
            String newAssigneeName, Long newAssigneeId,
            Long newAssignmentId) {
    }

    public record ConfirmHandoverRequest(
            Long newAssigneeId, String note, LocalDateTime deadline) {
    }
}
