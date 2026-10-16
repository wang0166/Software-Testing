## ADDED Requirements

### Requirement: Consistent API envelope and authentication
The backend SHALL expose JSON REST endpoints under `/api`, return a consistent response envelope containing `code`, `message`, and `data`, and require a valid bearer access token for protected endpoints. Authentication endpoints SHALL support login, refresh, logout, and current-user lookup.

#### Scenario: Authenticated request
- **WHEN** a client sends a valid bearer token to a protected endpoint
- **THEN** the backend resolves the caller identity and returns the endpoint result in the standard envelope

#### Scenario: Invalid or expired access token
- **WHEN** a client sends a missing, invalid, or expired access token to a protected endpoint
- **THEN** the backend returns an authentication error and does not disclose protected data

### Requirement: Role-scoped log access
The backend SHALL enforce log visibility on the server: employees see their own logs, team leaders see their team's logs, department managers see their department's logs, founders see company logs, and system administrators may read company logs. Client query parameters SHALL NOT broaden this scope. System administrators SHALL NOT create, edit, submit, or delete logs.

#### Scenario: Employee requests another user's log
- **WHEN** an employee requests a log authored by another user
- **THEN** the backend denies access or returns an empty result without exposing the log

#### Scenario: Manager queries outside assigned scope
- **WHEN** a team leader or department manager supplies filters targeting another team or department
- **THEN** the backend restricts results to the caller's assigned scope

#### Scenario: Administrator attempts to modify a log
- **WHEN** a system administrator calls a log write endpoint
- **THEN** the backend rejects the operation

### Requirement: Daily log lifecycle
The backend SHALL allow at most one log per author per server-local calendar day. The date SHALL be assigned by the server. A non-empty draft may be edited by its author before the configured cutoff and submitted once; a submitted log SHALL be immutable. Requests after the cutoff SHALL be rejected. At the configured cutoff, drafts SHALL become submitted and users without a log SHALL count as not submitted without requiring a persisted log row.

#### Scenario: Duplicate daily log
- **WHEN** an author creates a second log for the same server-local date
- **THEN** the backend rejects it with a conflict response

#### Scenario: Edit submitted log
- **WHEN** the author attempts to edit a submitted log
- **THEN** the backend rejects the mutation and leaves the log unchanged

#### Scenario: Cutoff processing
- **WHEN** the configured daily cutoff is reached
- **THEN** draft logs are transitioned to submitted and users with no log are counted as not submitted

### Requirement: Private direct-manager comment thread
The backend SHALL allow the log author and that author's direct manager to view and participate in a log's comment thread. Only the direct manager may initiate a comment and the author may reply. Other team members and higher-level managers SHALL NOT view or participate in the thread.

#### Scenario: Unauthorized manager reads comments
- **WHEN** a manager who is not the author's direct manager requests the thread
- **THEN** the backend denies access without returning comment content

#### Scenario: Author replies to manager
- **WHEN** the log author posts a reply referencing the manager's comment
- **THEN** the backend appends it to the same private thread

### Requirement: Administrative and statistics APIs
The backend SHALL provide role-appropriate statistics for submission rate, unsubmitted users, log counts, and 7/30-day trends. It SHALL provide administrator APIs for user, organization, role/permission, configuration, and audit management, while keeping administrator access to logs and statistics read-only.

#### Scenario: Statistics request
- **WHEN** an authorized user requests statistics
- **THEN** the backend calculates metrics only over that user's permitted organization scope

#### Scenario: Admin manages account
- **WHEN** an authenticated administrator with the relevant management permission creates, edits, disables/enables, or resets a user account
- **THEN** the backend applies the change and records the privileged operation in the audit log
