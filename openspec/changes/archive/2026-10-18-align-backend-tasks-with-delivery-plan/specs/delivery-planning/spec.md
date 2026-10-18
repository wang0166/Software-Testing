## ADDED Requirements

### Requirement: Align the backend task list with the schedule baseline

The backend task list SHALL organize backend work into Sprint 1 through Sprint 16 using the same dates and milestones as the project plan, and SHALL cover authentication and organization, logs, the task domain, and verification work instead of merging sprints or omitting task-domain scope.

#### Scenario: Sprint sections match the project plan

- **WHEN** the backend task list is compared with the project plan
- **THEN** it contains sixteen sprint sections with matching start/end dates and milestone identifiers, and no merged legacy sections remain

#### Scenario: Task domain work is scheduled

- **WHEN** the backend tasks for Sprint 6 through Sprint 10 are reviewed
- **THEN** dispatch, receipt, progress, invitation, review and return, personal tasks, company display content, data map, and calendar work are each assigned to a sprint

#### Scenario: Verification work is scheduled

- **WHEN** the backend tasks for Sprint 11 through Sprint 16 are reviewed
- **THEN** they include task API contract tests, organization-constraint tests, task end-to-end and isolation tests, performance verification covering task lists, data map and calendar with a 99% success-rate target, and US-30 to US-41 acceptance evidence
