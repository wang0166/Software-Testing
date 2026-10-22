## MODIFIED Requirements

### Requirement: Authenticate with administrator-issued credentials

The system SHALL authenticate users with a username and password issued by the administrator, and SHALL return an access token, a refresh token, token metadata, and a user summary on success. The user summary SHALL include the effective permission codes so that clients can gate features immediately after login without an extra request. The system SHALL NOT expose a registration endpoint or any self-service account-creation path.

#### Scenario: Valid credentials return tokens
- **WHEN** a user submits a valid username and password to `POST /api/auth/login`
- **THEN** the response contains `accessToken`, `refreshToken`, `tokenType`, `expiresIn`, and a `user` summary with role, organization membership, and a `permissions` array

#### Scenario: Permissions match the current user endpoint
- **WHEN** the same token is used to call `GET /api/auth/me`
- **THEN** the returned permission codes are identical to those in the login response

#### Scenario: Invalid credentials are rejected
- **WHEN** a user submits a wrong username or password
- **THEN** the response uses HTTP 401 and business code `40101` without revealing which field was wrong

#### Scenario: No registration endpoint exists
- **WHEN** an unauthenticated caller looks for a registration endpoint
- **THEN** no such endpoint exists under `/api/auth`

#### Scenario: Failed login counter resets after success
- **WHEN** a user logs in successfully after earlier failed attempts
- **THEN** the consecutive failure counter for that account is reset to zero

### Requirement: Reject disabled accounts

The system SHALL reject login and authenticated requests for accounts disabled by the administrator using a business code distinct from the lockout code, and SHALL allow access again after the account is enabled.

#### Scenario: Disabled account cannot log in
- **WHEN** a disabled account submits correct credentials
- **THEN** the response uses HTTP 401 and business code `40104` with a message stating that the account is disabled

#### Scenario: Locked and disabled codes are distinguishable
- **WHEN** a client compares the responses for a locked account and a disabled account
- **THEN** the locked response uses business code `40103` with HTTP 423 while the disabled response uses `40104` with HTTP 401

#### Scenario: Disabled account cannot use an existing token
- **WHEN** a disabled account calls a protected endpoint with a previously issued access token
- **THEN** the server rejects the request instead of trusting the token until expiry

#### Scenario: Enabled account regains access
- **WHEN** the administrator enables the account again
- **THEN** the account can log in and use protected endpoints normally
