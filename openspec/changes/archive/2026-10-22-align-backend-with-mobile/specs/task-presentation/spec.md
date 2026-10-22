## ADDED Requirements

### Requirement: Serve the task map from a single paginated endpoint

The system SHALL expose `GET /api/task-map` requiring `task:execute` or `task:self`. The endpoint SHALL return, in one paginated list, the caller's dispatched assignments and the caller's self-created tasks, each item identifying its `source` as `DISPATCHED` or `PERSONAL`. Items SHALL include `name`, `details`, execution status, urgency, deadline, and review state where applicable, and SHALL expose `assignmentId` or `personalTaskId` according to the source.

#### Scenario: Map merges dispatched and personal records
- **WHEN** the caller has one dispatched assignment and one personal task
- **THEN** the response contains both items with `source` set correctly and a matching identifier field

#### Scenario: Map excludes other users' records
- **WHEN** another user owns tasks
- **THEN** none of those records appear in the caller's map

#### Scenario: Administrator calls the map
- **WHEN** an administrator calls `GET /api/task-map`
- **THEN** the request fails with HTTP 403 and business code `40310`
