## MODIFIED Requirements

### Requirement: Expose received tasks and per-recipient progress
The system SHALL expose `GET /api/tasks/received`, `GET /api/tasks/assignments/{assignmentId}`, and `PATCH /api/tasks/assignments/{assignmentId}/progress`. Each recipient SHALL only read and update their own assignment. Results SHALL exclude pending or withdrawn dispatch proposals and SHALL include execution status, review status, completion percentage, issue/unread indicators, and the latest progress summary when available. Progress SHALL follow `NOT_STARTED` → `IN_PROGRESS` → `COMPLETED`, and SHALL be rejected while the assignment's review state is `PENDING` or `APPROVED`.

#### Scenario: Recipient sees only received live tasks
- **WHEN** an employee requests received tasks
- **THEN** the response contains only live assignments where that employee is the assignee and excludes pending proposals

#### Scenario: Recipient updates their own progress
- **WHEN** an assignee patches the progress of their own assignment to `IN_PROGRESS`
- **THEN** only that assignment's status changes and the response includes the current percentage and latest progress metadata

#### Scenario: Another user updates the assignment
- **WHEN** a user who is not the assignee calls the progress endpoint
- **THEN** the request fails with HTTP 403 and business code `40312`

#### Scenario: Progress change while review is pending
- **WHEN** an assignee changes progress while the assignment is pending review or approved
- **THEN** the request fails with HTTP 409 and business code `40910`

#### Scenario: Assignment detail includes review history
- **WHEN** the assignee or the sender calls `GET /api/tasks/assignments/{assignmentId}`
- **THEN** the response contains the assignment state and an ordered review history
