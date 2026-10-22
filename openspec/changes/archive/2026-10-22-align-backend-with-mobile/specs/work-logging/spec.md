## ADDED Requirements

### Requirement: Enforce one submitted work log per user per day

The system SHALL allow each active non-administrator user to own at most one work log per calendar date (`Asia/Shanghai`), and SHALL enforce uniqueness at the database level. A log SHALL move from `DRAFT` to `SUBMITTED` only through the submit operation.

#### Scenario: Duplicate log for the same date
- **WHEN** a user who already has a log for today calls `POST /api/logs`
- **THEN** the request fails with HTTP 409 and business code `40901`

#### Scenario: Submit sets the submission timestamp
- **WHEN** the author submits a draft log through `POST /api/logs/{id}/submit`
- **THEN** the log status becomes `SUBMITTED` and `submittedAt` is populated

### Requirement: Enforce the log deadline and post-submission immutability

The system SHALL reject log creation, content update, and submission after the configured `log_deadline` time, and SHALL reject content updates for an already submitted log.

#### Scenario: Update after submission
- **WHEN** the author updates the content of a `SUBMITTED` log
- **THEN** the request fails with HTTP 409 and business code `40902`

#### Scenario: Create or submit after the deadline
- **WHEN** the current local time is later than `log_deadline` and the author creates or submits a log
- **THEN** the request fails with HTTP 409 and business code `40903`

### Requirement: Scope log visibility by role

The system SHALL return logs according to the caller's role: an employee sees only their own logs, a team leader sees logs of their team, a department manager sees logs of their department, and the founder sees all logs. The administrator SHALL only read and MUST NOT create, update, submit, or comment.

#### Scenario: Team leader lists team logs
- **WHEN** a team leader calls `GET /api/logs`
- **THEN** only logs authored by members of that leader's team are returned

#### Scenario: Administrator attempts to write
- **WHEN** an administrator calls `POST /api/logs` or `POST /api/logs/{id}/comments`
- **THEN** the request fails with HTTP 403 and business code `40301`

### Requirement: Restrict log comments to the author and direct superior

The system SHALL allow only the log author and the author's direct superior to read and create comments on a log. Comments SHALL support an optional `parentId` for replies and SHALL return the author identifier, author name, content, and creation time.

#### Scenario: Direct superior comments
- **WHEN** a team leader comments on an employee's submitted log in the same team
- **THEN** the comment is created and returned to both parties

#### Scenario: Unrelated user comments
- **WHEN** a user who is neither the author nor the direct superior posts a comment
- **THEN** the request fails with HTTP 403 and business code `40302`

### Requirement: Expose paginated log endpoints

The system SHALL expose `GET /api/logs` with optional `date` and `status` filters, `GET /api/logs/{id}`, `POST /api/logs`, `PUT /api/logs/{id}`, `POST /api/logs/{id}/submit`, `GET /api/logs/{id}/comments`, and `POST /api/logs/{id}/comments`. List responses SHALL use the unified `{total,page,size,items}` page shape with a default size of 20 and a maximum of 100.

#### Scenario: Filter by date
- **WHEN** a client calls `GET /api/logs?date=2026-10-22`
- **THEN** only logs whose `logDate` equals that date are returned

#### Scenario: Detail returns the documented fields
- **WHEN** an authorized user calls `GET /api/logs/{id}`
- **THEN** the response contains `id`, `authorId`, `authorName`, `logDate`, `content`, `status`, `isImportant`, and `submittedAt`
