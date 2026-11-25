package com.pandora.log.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public final class CrmDtos {
    private CrmDtos() {
    }

    public record CustomerDto(
            Long id, String name, String category, String business,
            String memberTier, LocalDate memberExpiresAt, String maskedContact,
            String ownerName, String remark, String linkedMallMemberId,
            String linkedTicketCardId, Long ownerId, Long departmentId,
            Long teamId, int annualCardUsed, int annualCardLimit,
            boolean sensitive) {
    }

    public record CreateCustomerRequest(
            String name, String category, String business, String memberTier,
            LocalDate memberExpiresAt, String maskedContact, String remark,
            String linkedMallMemberId, String linkedTicketCardId,
            Long ownerId, Long departmentId, Long teamId, Boolean sensitive) {
    }

    public record BenefitDto(
            Long id, Long customerId, String title, int total, int used,
            String serviceStatus) {
    }

    public record ActivityDto(
            Long id, Long customerId, String kind, String title, String status,
            LocalDate date, String ownerName, String note,
            List<Long> participantIds, List<String> participantNames) {
    }

    public record CreateActivityRequest(
            Long customerId, String kind, String title, LocalDate date,
            String status, List<Long> participantIds, String note,
            Long revenueAmountFen) {
    }

    public record RevenueSummaryDto(
            String month, long totalAmountFen, long orderCount,
            Map<String, Long> byBusinessFen) {
    }

    public record EmployeeArchiveDto(
            Long id, Long departmentId, String name, String department,
            String duty, String role, String accountStatus,
            LocalDate contractEnd, String contractArchiveStatus) {
    }

    public record CreateEmployeeArchiveRequest(
            Long userId, String name, String department, String duty,
            LocalDate contractEnd, String contractArchiveStatus) {
    }
}
