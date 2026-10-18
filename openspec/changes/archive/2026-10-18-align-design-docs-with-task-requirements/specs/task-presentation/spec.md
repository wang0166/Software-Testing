## ADDED Requirements

### Requirement: Preserve log behavior in task-facing pages
Task-facing pages SHALL preserve existing log drafting, immutable submission, service-side dates, cutoff behavior, feedback privacy, and log-statistics definitions. Task completion MUST NOT replace log submission status or alter log metrics.

#### Scenario: Submitted log opened in mind map
- **WHEN** the user double-taps an already submitted log in the mind-map page
- **THEN** the log remains read-only and cannot be modified

### Requirement: Present mind map and personal panel modules
The mind-map page SHALL show company important matters, company important tasks, personal work tasks, and personal logs in top-left, top-right, bottom-left, and bottom-right positions. Personal tasks and editable log drafts SHALL support in-place double-tap editing without navigation. The personal panel SHALL show logs, personal work tasks, dispatch, and received tasks in those respective positions, with dispatch restricted to authorized senders.

#### Scenario: Edit own draft in place
- **WHEN** the user double-taps their editable log draft before the cutoff in the mind-map page
- **THEN** the draft enters inline editing without navigating to another page and retains normal log validation

#### Scenario: Employee opens personal panel
- **WHEN** an employee without dispatch permission opens the personal panel
- **THEN** received tasks and personal task entries remain available while dispatch is not enabled

### Requirement: Show a read-only personal task data map
The data map SHALL display only tasks assigned to the current user and their self-created tasks, including name, deadline, urgency, and personal progress. Missing personal-task dates and urgency SHALL be blank. It SHALL exclude company display content, provide no editing, and reflect changes made through source entries.

#### Scenario: Personal task has no deadline
- **WHEN** a self-created task is displayed in the data map
- **THEN** its deadline and urgency cells are blank rather than fabricated defaults

#### Scenario: Progress changes in received tasks
- **WHEN** a user updates their execution progress in the received-task entry and returns to the data map
- **THEN** the data map displays the updated personal progress without offering an edit operation

### Requirement: Render task and log calendar views
The view page SHALL default to the phone's current month and support month, seven-day week, and white-background day views. Month/week views SHALL mark authorized log dates red and dates within the current user's received dispatched-task ranges green, including both endpoints. Green SHALL take precedence on overlap. Personal tasks and company display content SHALL NOT create calendar marks; colors SHALL NOT encode urgency or progress.

#### Scenario: Task and log overlap
- **WHEN** a date has both a log and a received dispatched task within its start/deadline range
- **THEN** the date is marked green only

#### Scenario: Task range boundary
- **WHEN** a task begins on Monday and ends on Wednesday
- **THEN** Monday, Tuesday, and Wednesday are included in its green calendar range

#### Scenario: Switch to day view
- **WHEN** the user selects a day view
- **THEN** the page displays that day's authorized logs and received dated tasks on a white background
