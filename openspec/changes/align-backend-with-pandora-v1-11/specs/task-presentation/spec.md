## ADDED Requirements

### Requirement: Supply mobile task-board and subordinate presentation data
The task-board and task-map APIs SHALL return caller-scoped live assignments with stable assignment/task ids, details, deadline, urgency, execution/review state, completion percentage, and latest progress/issue metadata. Subordinate summaries SHALL be read-only and limited to the caller's permitted reporting hierarchy.

#### Scenario: Employee opens task board
- **WHEN** an employee requests the task-board data
- **THEN** the server returns only that employee's received assignments and their current progress fields

#### Scenario: Manager opens subordinate detail
- **WHEN** a manager requests an authorized subordinate's assignment history
- **THEN** the server returns read-only progress and issue state without permitting edits

#### Scenario: Cross-scope task access
- **WHEN** a caller requests a task outside their assignment or reporting scope
- **THEN** the server rejects the request without leaking task content
