# authentication Specification

## Purpose

Define authentication with administrator-issued credentials, access and refresh token sessions with logout revocation, lockout after repeated login failures, rejection of disabled accounts, and exposure of the current user context with server-resolved permissions.

## Requirements

### Requirement: Authenticate with administrator-issued credentials

The system SHALL authenticate users with a username and password issued by the administrator, and SHALL return an access token, a refresh token, token metadata, and a user summary on success. The system SHALL NOT expose a registration endpoint or any self-service account-creation path.

#### Scenario: Valid credentials return tokens

- **WHEN** a user submits a valid username and password to `POST /api/auth/login`
- **THEN** the response contains `accessToken`, `refreshToken`, `tokenType`, `expiresIn`, and a `user` summary with role and organization membership

#### Scenario: Invalid credentials are rejected

- **WHEN** a user submits a wrong username or password
- **THEN** the response uses HTTP 401 and business code `40101` without revealing which field was wrong

#### Scenario: No registration endpoint exists

- **WHEN** an unauthenticated caller looks for a registration endpoint
- **THEN** no such endpoint exists under `/api/auth`

#### Scenario: Failed login counter resets after success

- **WHEN** a user logs in successfully after earlier failed attempts
- **THEN** the consecutive failure counter for that account is reset to zero

### Requirement: Refresh and revoke sessions

The system SHALL allow a valid refresh token to obtain a new access token and SHALL revoke the refresh token on logout. Logout SHALL be idempotent for an already revoked token.

#### Scenario: Refresh returns a new access token

- **WHEN** a valid, unexpired refresh token is submitted to `POST /api/auth/refresh`
- **THEN** a new access token is returned and the refresh token remains subject to the documented rotation policy

#### Scenario: Invalid or expired refresh token is rejected

- **WHEN** an expired, revoked, or unknown refresh token is submitted
- **THEN** the response uses HTTP 401 and business code `40102`

#### Scenario: Logout is idempotent

- **WHEN** logout is called twice with the same refresh token
- **THEN** both calls succeed and the token is no longer usable

### Requirement: Lock accounts after repeated login failures

The system SHALL count consecutive login failures and lock the account for the configured duration once the configured threshold is reached, using the values stored in system configuration.

#### Scenario: Threshold reached triggers lockout

- **WHEN** consecutive failed logins reach `login_max_failures`
- **THEN** the account is locked for `login_lock_minutes` and further attempts return HTTP 423 and business code `40103`

#### Scenario: Successful login clears the counter

- **WHEN** a login succeeds before the threshold is reached
- **THEN** the failure counter is cleared and no lockout occurs

### Requirement: Reject disabled accounts

The system SHALL reject login and authenticated requests for accounts disabled by the administrator, and SHALL allow access again after the account is enabled.

#### Scenario: Disabled account cannot log in

- **WHEN** a disabled account submits correct credentials
- **THEN** the response uses HTTP 401 and business code `40103`

#### Scenario: Disabled account cannot use an existing token

- **WHEN** a disabled account calls a protected endpoint with a previously issued access token
- **THEN** the server rejects the request instead of trusting the token until expiry

#### Scenario: Enabled account regains access

- **WHEN** the administrator enables the account again
- **THEN** the account can log in and use protected endpoints normally

### Requirement: Expose the current user context

The system SHALL expose the current account summary, role, organization membership, and effective permission codes through `GET /api/auth/me`, with permissions resolved on the server.

#### Scenario: Current user is returned

- **WHEN** an authenticated user calls `GET /api/auth/me`
- **THEN** the response contains the user summary, role, department and team identifiers where applicable, and the effective permission codes

#### Scenario: Administrator has no task permissions

- **WHEN** the current user has the administrator role
- **THEN** the returned permission codes do not include `task:dispatch`, `task:execute`, or `task:self`
