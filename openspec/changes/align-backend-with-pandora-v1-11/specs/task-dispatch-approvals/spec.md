## ADDED Requirements

### Requirement: Keep dispatch proposals pending until approval
The system SHALL expose dispatch-request endpoints for creating, listing, editing, and withdrawing a proposal. A proposal SHALL include task content, dates, urgency/type, and assignee ids; invalid recipients or dates SHALL reject the entire request. A pending proposal SHALL NOT appear in `/api/tasks/received` or live task-map results.

#### Scenario: Create pending proposal
- **WHEN** an authorized sender submits a valid dispatch request
- **THEN** the server stores a PENDING request and returns its status without creating received assignments

#### Scenario: Approve proposal
- **WHEN** an authorized reviewer approves a pending proposal
- **THEN** the server creates the task and assignments exactly once and the recipients can see it

#### Scenario: Withdraw proposal
- **WHEN** its requester withdraws a pending proposal
- **THEN** the request becomes WITHDRAWN and a repeated withdrawal is idempotent

### Requirement: Audit edits and deletion of published tasks
The system SHALL represent edits and deletion of published tasks as PENDING change requests, enforce one unresolved request per task/action, and require an authorized reviewer. Approval SHALL apply the requested change transactionally; rejection SHALL leave the published task unchanged.

#### Scenario: Edit requires review
- **WHEN** a sender changes the details or assignees of a published task
- **THEN** the server records a PENDING UPDATE request and keeps the live task unchanged until review

#### Scenario: Unauthorized review is denied
- **WHEN** a user without the configured approval permission reviews a request
- **THEN** the server returns HTTP 403 and does not change request or task state
