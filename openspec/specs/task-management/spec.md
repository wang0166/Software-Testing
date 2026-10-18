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
