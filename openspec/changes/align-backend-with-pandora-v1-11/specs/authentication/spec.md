## ADDED Requirements

### Requirement: Support mobile password request and change workflow
The system SHALL expose unauthenticated password reset requests and authenticated password-change request/status/completion endpoints used by the mobile client. Reset and change operations SHALL be rate-limited, audited, and SHALL never reveal whether an unrelated username exists.

#### Scenario: Request reset
- **WHEN** a client posts a username to `POST /api/auth/password-reset-requests`
- **THEN** the server accepts the request with a generic response and applies the configured limiter

#### Scenario: Request and complete authenticated change
- **WHEN** an authenticated user creates a change request, reads its status, and submits a new password after approval
- **THEN** the server enforces the request state transition, updates credentials, and invalidates prior sessions according to policy

#### Scenario: Invalid change state
- **WHEN** a user attempts to complete a missing, rejected, or already completed request
- **THEN** the server rejects the operation without changing the password
