## ADDED Requirements

### Requirement: Expose read-only company display content

The system SHALL expose `GET /api/company-matters` and `GET /api/company-important-tasks` as read-only, paginated endpoints requiring the `content:read` permission. Results SHALL be ordered by `sort_order` ascending and then by `id` ascending.

#### Scenario: User with content permission reads matters
- **WHEN** a user holding `content:read` calls `GET /api/company-matters`
- **THEN** the response contains the published matters with `id`, `title`, and `content`

#### Scenario: Missing permission
- **WHEN** a user without `content:read` calls either endpoint
- **THEN** the request fails with HTTP 403 and business code `40301`

#### Scenario: No write path exists
- **WHEN** a client attempts to create or update company display content through these endpoints
- **THEN** no write endpoint exists under `/api/company-matters` or `/api/company-important-tasks`

### Requirement: Keep company display content out of task data

The system SHALL return company matters and company important tasks only through their dedicated endpoints, and these records MUST NOT appear in task lists, task maps, calendars, or statistics.

#### Scenario: Task map excludes display content
- **WHEN** a user loads `GET /api/task-map`
- **THEN** no record originating from `company_matters` or `company_important_tasks` is present
