# task-management Specification

## Purpose

Define direct-report task dispatch, sender and recipient ownership of content versus execution progress, per-recipient completion invitations and review, and private self-created personal tasks.

## Requirements

### Requirement: Dispatch tasks only to direct reports
The system SHALL permit the founder to dispatch to department heads, department heads to their team leaders, and team leaders to their employees. A dispatched task SHALL contain name, details, start date, deadline, urgency, and one or more recipients. The deadline MUST NOT precede the start date.

#### Scenario: Multiple direct recipients
- **WHEN** a team leader dispatches one task to two employees directly reporting to that leader
- **THEN** both employees receive independent execution records for the same shared task content

#### Scenario: Cross-level or cross-organization dispatch
- **WHEN** a sender selects any recipient who is not a direct report in the sender's organization
- **THEN** the system rejects the dispatch without partially creating the task

#### Scenario: Invalid date range
- **WHEN** a task deadline is earlier than its start date
- **THEN** the system rejects the task content

### Requirement: Enforce content and progress ownership
The sender SHALL edit shared task content but MUST NOT update a recipient's execution progress. A recipient SHALL update only their own execution progress and MUST NOT edit shared content or another recipient's execution record. Unrelated users MUST NOT gain task access through log-reading permissions.

#### Scenario: Recipient attempts content edit
- **WHEN** a recipient submits a change to the shared task deadline or details
- **THEN** the system rejects the change

#### Scenario: Sender attempts execution update
- **WHEN** the sender attempts to mark a recipient's execution as completed outside the review operation
- **THEN** the system rejects the operation

#### Scenario: Another user accesses a private record
- **WHEN** an unrelated user or an administrator relying only on global log-reading access requests a recipient's task record
- **THEN** the system denies access

### Requirement: Isolate completion invitations and review per recipient
Each recipient SHALL maintain execution progress as not started, in progress, or completed. A completed recipient SHALL be able to invite the sender to check their work, entering pending review. Only that task's sender SHALL approve or return the invited recipient's work. Return SHALL preserve the review outcome and put that recipient's execution back in progress, permitting another completion and invitation. Review MUST NOT change another recipient's record or require push notifications.

#### Scenario: Independent invitation and approval
- **WHEN** one of two recipients completes a task, invites the sender, and receives approval
- **THEN** only that recipient's review becomes approved and the second recipient's progress remains unchanged

#### Scenario: Return and resubmit
- **WHEN** the sender returns a pending review
- **THEN** that recipient returns to in-progress execution and can later complete and invite review again

#### Scenario: Invitation before completion
- **WHEN** a recipient invites review while execution is not completed
- **THEN** the system rejects the transition without altering the record

### Requirement: Maintain private self-created tasks
The personal top-ten work-task entry SHALL create and edit the current user's own tasks using name, details, and execution status. These tasks SHALL be visible and editable only by their owner, SHALL use not-started, in-progress, and completed progress, and SHALL NOT require dates, urgency, recipients, or review. The mind-map and personal-panel entries MUST use the same records.

#### Scenario: Edit from either entry
- **WHEN** the owner edits a personal task from the personal panel
- **THEN** the mind-map entry displays the same updated task

#### Scenario: Another user accesses a personal task
- **WHEN** a different user requests the personal task
- **THEN** the system denies reading and editing regardless of that user's log-reading scope

### Requirement: Expose task dispatch through mobile endpoints

The system SHALL expose `GET /api/tasks/recipients`, `POST /api/tasks`, `GET /api/tasks/dispatched`, and `GET /api/tasks/{taskId}`. Recipients SHALL be limited to the caller's direct reports. Dispatch SHALL create the shared task content and one execution assignment per recipient in a single transaction, and SHALL reject the whole request if any recipient is invalid. Dispatch SHALL require `task:dispatch`.

#### Scenario: Dispatch to multiple direct reports
- **WHEN** a team leader posts one task with two direct-report assignees
- **THEN** one task is created and the response contains one assignment per recipient

#### Scenario: Invalid recipient rejects the whole dispatch
- **WHEN** the assignee list contains a user who is not a direct report
- **THEN** the request fails with HTTP 400 and business code `40003` and no task or assignment is created

#### Scenario: Caller cannot dispatch
- **WHEN** an employee or administrator calls `POST /api/tasks`
- **THEN** the request fails with HTTP 403 and business code `40310`

#### Scenario: Sender lists dispatched tasks
- **WHEN** the sender calls `GET /api/tasks/dispatched`
- **THEN** only tasks created by that sender are returned with `assigneeCount` and the aggregated review state

### Requirement: Expose received tasks and per-recipient progress

The system SHALL expose `GET /api/tasks/received`, `GET /api/tasks/assignments/{assignmentId}`, and `PATCH /api/tasks/assignments/{assignmentId}/progress`. Each recipient SHALL only read and update their own assignment. Progress SHALL follow `NOT_STARTED` → `IN_PROGRESS` → `COMPLETED`, and SHALL be rejected while the assignment's review state is `PENDING` or `APPROVED`.

#### Scenario: Recipient updates their own progress
- **WHEN** an assignee patches the progress of their own assignment to `IN_PROGRESS`
- **THEN** only that assignment's status changes

#### Scenario: Another user updates the assignment
- **WHEN** a user who is not the assignee calls the progress endpoint
- **THEN** the request fails with HTTP 403 and business code `40312`

#### Scenario: Progress change while review is pending
- **WHEN** an assignee changes progress while the assignment is pending review or approved
- **THEN** the request fails with HTTP 409 and business code `40910`

#### Scenario: Assignment detail includes review history
- **WHEN** the assignee or the sender calls `GET /api/tasks/assignments/{assignmentId}`
- **THEN** the response contains the assignment state and an ordered review history

### Requirement: Expose completion invitations and sender review

The system SHALL expose `POST /api/tasks/assignments/{assignmentId}/review-invitations` and `POST /api/tasks/assignments/{assignmentId}/review`. Only the assignee SHALL invite review, and only when progress is `COMPLETED`. Invitation SHALL set the review state to `PENDING`. Only the sender SHALL review, using result `APPROVED` or `RETURNED`. Approval SHALL set the review state to `APPROVED`; return SHALL set it back to `IN_PROGRESS` while preserving the review record.

#### Scenario: Invitation before completion
- **WHEN** the assignee invites review while progress is not `COMPLETED`
- **THEN** the request fails with HTTP 409 and business code `40910`

#### Scenario: Duplicate invitation
- **WHEN** the assignee invites review while a review is already pending
- **THEN** the request fails with HTTP 409 and business code `40911`

#### Scenario: Sender approves
- **WHEN** the sender reviews a pending assignment with result `APPROVED`
- **THEN** the review state becomes `APPROVED` and a review record with action `APPROVED` is stored

#### Scenario: Sender returns the work
- **WHEN** the sender reviews a pending assignment with result `RETURNED`
- **THEN** progress returns to `IN_PROGRESS`, the review record is preserved, and the assignee can complete and invite again

#### Scenario: Non-sender reviews
- **WHEN** a user other than the task sender calls the review endpoint
- **THEN** the request fails with HTTP 403 and business code `40313`

#### Scenario: Review already handled
- **WHEN** the sender reviews an assignment whose review state is not `PENDING`
- **THEN** the request fails with HTTP 409 and business code `40912`

### Requirement: Expose private personal task endpoints

The system SHALL expose `GET /api/personal-tasks`, `POST /api/personal-tasks`, and `PUT /api/personal-tasks/{id}` requiring `task:self`. Personal tasks SHALL contain name, details, and execution status only, SHALL default to `NOT_STARTED`, and SHALL be readable and editable only by their owner.

#### Scenario: Owner creates and updates a personal task
- **WHEN** the owner creates a personal task and later updates its status to `IN_PROGRESS`
- **THEN** both operations succeed and the listed task reflects the new status

#### Scenario: Another user updates a personal task
- **WHEN** a different user calls `PUT /api/personal-tasks/{id}`
- **THEN** the request fails with HTTP 403 and the personal task is unchanged
