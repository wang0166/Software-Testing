## ADDED Requirements

### Requirement: Aggregate logs and tasks into a daily calendar

The system SHALL expose `GET /api/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD` and return one entry per date in the inclusive range. Each entry SHALL contain the date, `logCount`, `taskCount`, a `mark`, and the detailed `logs` and `tasks` for that date. The caller's logs SHALL follow their log visibility scope and tasks SHALL be limited to assignments and self-created tasks owned by the caller.

#### Scenario: A day with both records
- **WHEN** the caller has one task due and one submitted log on a date
- **THEN** that entry reports `taskCount=1`, `logCount=1`, and includes both records

#### Scenario: Empty day
- **WHEN** a date in the range has no logs or tasks
- **THEN** the entry reports `logCount=0`, `taskCount=0`, `mark=NONE`, and empty arrays

### Requirement: Derive the calendar mark from task and log presence

The system SHALL set `mark` to `GREEN` when the day has at least one task, otherwise to `RED` when the day has at least one log, otherwise to `NONE`.

#### Scenario: Task takes precedence over log
- **WHEN** a day has both a task and a log
- **THEN** `mark` is `GREEN`

#### Scenario: Log-only day
- **WHEN** a day has a log but no task
- **THEN** `mark` is `RED`

### Requirement: Enforce calendar range and permission limits

The system SHALL require `task:execute` and SHALL reject a range longer than 31 days or a `from` date after `to`.

#### Scenario: Range too long
- **WHEN** a client requests a range spanning more than 31 days
- **THEN** the request fails with HTTP 400 and business code `40001`

#### Scenario: Administrator requests the calendar
- **WHEN** an administrator calls `GET /api/calendar`
- **THEN** the request fails with HTTP 403 and business code `40310`
