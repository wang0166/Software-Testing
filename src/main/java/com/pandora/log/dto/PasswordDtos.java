package com.pandora.log.dto;

import java.time.OffsetDateTime;
import com.pandora.log.dto.AdminDtos.StrictRequest;
import jakarta.validation.constraints.*;

public final class PasswordDtos {
    private PasswordDtos() { }
    public record ResetRequest(@NotBlank @Size(max=100) String username) implements StrictRequest { }
    public record ChangeRequest(@NotBlank @Size(min=8,max=72) String newPassword) implements StrictRequest {
        @Override public String toString() { return "ChangeRequest[凭据已隐藏]"; }
    }
    public record ResetCompletion(@NotBlank @Size(max=100) String token,
            @NotBlank @Size(min=8,max=72) String newPassword) implements StrictRequest {
        @Override public String toString() { return "ResetCompletion[凭据已隐藏]"; }
    }
    public record ReviewRequest(@NotBlank @Pattern(regexp="APPROVED|REJECTED") String decision,
            boolean identityVerified, @NotBlank @Size(max=200) String currentPassword) implements StrictRequest {
        @Override public String toString() { return "ReviewRequest[凭据已隐藏]"; }
    }
    public record Accepted(String message) { }
    public record StatusDto(String status, OffsetDateTime expiresAt) { }
    public record RequestDto(Long id, Long userId, String username, String realName, String kind,
            String status, OffsetDateTime createdAt, OffsetDateTime expiresAt, Long reviewerId) { }
    public record ReviewDto(Long id, String status, OffsetDateTime expiresAt, String recoveryToken) {
        @Override public String toString() { return "ReviewDto[恢复凭据已隐藏]"; }
    }
}
