package com.pandora.log.dto;

import java.time.OffsetDateTime;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonAnySetter;

/** 管理接口显式返回资料字段，凭据不进入响应 DTO。 */
public final class AdminDtos {
    private AdminDtos() { }
    public interface StrictRequest {
        @JsonAnySetter
        default void rejectUnknown(String field, Object value) {
            throw new IllegalArgumentException("不支持的请求字段");
        }
    }

    public record IdDto(Long id) { }
    public record UserDto(Long id, String username, String realName, String role, String status,
            Long departmentId, Long teamId, String departmentName, String teamName,
            String phone, String gender, String idNumber) { }
    public record CreateUserRequest(
            @NotBlank @Pattern(regexp = "[a-z0-9_]{3,20}") String username,
            @NotBlank @Pattern(regexp = "1[0-9]{10}") String phone,
            @NotBlank @Size(min = 6, max = 72) String password,
            @NotBlank @Size(max = 64) String realName,
            @NotBlank String role, Long departmentId, Long teamId,
            @Pattern(regexp = "|男|女") String gender,
            @Pattern(regexp = "|[0-9]{17}[0-9Xx]") String idNumber) implements StrictRequest {
        @Override public String toString() { return "CreateUserRequest[redacted]"; }
    }
    public record UpdateUserRequest(@NotBlank @Size(max = 64) String realName,
            @NotBlank String role, Long departmentId, Long teamId) implements StrictRequest { }
    public record UserStatusRequest(@NotNull @Min(0) @Max(1) Integer status) implements StrictRequest { }
    public record PasswordRequest(@NotBlank @Size(min = 6, max = 72) String password) implements StrictRequest {
        @Override public String toString() { return "PasswordRequest[redacted]"; }
    }
    public record CompanyDto(Long id, String name, Long founderId) { }
    public record CompanyRequest(@NotBlank @Size(max = 100) String name) implements StrictRequest { }
    public record DepartmentDto(Long id, String name, String description, Long companyId, Long managerId) { }
    public record TeamDto(Long id, String name, String description, Long departmentId, Long leaderId) { }
    public record DepartmentRequest(@NotBlank @Size(max = 100) String name,
            @NotNull @Positive Long companyId, @Size(max = 500) String description) implements StrictRequest { }
    public record TeamRequest(@NotBlank @Size(max = 100) String name,
            @NotNull @Positive Long departmentId, @Size(max = 500) String description, Long leaderId) implements StrictRequest { }
    public record MatterDto(Long id, String title, String content, int sortOrder,
            OffsetDateTime startDate, OffsetDateTime deadline, OffsetDateTime updatedAt) { }
    public record MatterRequest(@NotBlank @Size(max = 200) String title,
            @NotBlank @Size(max = 100000) String content, @NotNull Integer sortOrder,
            @NotNull @JsonFormat(without = JsonFormat.Feature.ADJUST_DATES_TO_CONTEXT_TIME_ZONE) OffsetDateTime startDate,
            @NotNull @JsonFormat(without = JsonFormat.Feature.ADJUST_DATES_TO_CONTEXT_TIME_ZONE) OffsetDateTime deadline) implements StrictRequest { }
    public record AuditDto(Long id, String actor, String action, String target,
            OffsetDateTime time, String result) { }
}
