## MODIFIED Requirements

### Requirement: Render task and log calendar views

The view page SHALL default to the phone's current month and SHALL provide day, week, and month view selection controls in the top-left corner. It SHALL support month, seven-day week, and white-background day views. Month/week views SHALL mark authorized log dates red and dates within the current user's received dispatched-task ranges green, including both the start and deadline endpoints. Green SHALL take precedence on overlap. Personal tasks and company display content SHALL NOT create calendar marks; colors SHALL NOT encode urgency or progress.

#### Scenario: Task and log overlap

- **WHEN** a date has both a log and a received dispatched task within its start/deadline range
- **THEN** the date is marked green only

#### Scenario: Task range boundary

- **WHEN** a task begins on Monday and ends on Wednesday
- **THEN** Monday, Tuesday, and Wednesday are included in its green calendar range

#### Scenario: Switch to day view

- **WHEN** the user selects a day view
- **THEN** the page displays that day's authorized logs and received dated tasks on a white background

#### Scenario: Select a calendar view from the top-left

- **WHEN** the user opens the view page
- **THEN** day, week, and month selection controls are available in the top-left corner and the current selection remains visible
