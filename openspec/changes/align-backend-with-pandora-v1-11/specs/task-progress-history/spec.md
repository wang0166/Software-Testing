## ADDED Requirements

### Requirement: Record detailed assignment progress
The system SHALL expose `POST /api/tasks/assignments/{assignmentId}/progress-updates` accepting execution status, an integer completion percentage from 0 to 100, and an optional note. Only the assignment's assignee may create a record, and the endpoint SHALL update the assignment snapshot atomically.

#### Scenario: Assignee records progress
- **WHEN** an assignee submits `IN_PROGRESS`, 40, and a note for their assignment
- **THEN** the server stores an immutable event, updates the assignment percentage and status, and returns its id and creation time

#### Scenario: Invalid percentage is rejected
- **WHEN** a client submits a percentage below 0 or above 100, or a non-completed status with 100 percent
- **THEN** the server returns a validation error and changes neither the event nor the assignment

### Requirement: Expose permission-scoped progress history
The system SHALL expose chronological progress history for an assignee and read-only history for an authorized manager viewing a direct or indirect subordinate. Unrelated users, senders without subordinate scope, and users who are not the assignee SHALL be denied.

#### Scenario: Assignee reads history
- **WHEN** an assignee requests `GET /api/tasks/assignments/{assignmentId}/progress-updates`
- **THEN** the server returns that assignment's events newest first

#### Scenario: Unrelated user is denied
- **WHEN** a user outside the assignment's permitted reporting scope requests its history
- **THEN** the server returns HTTP 403 without exposing event data
