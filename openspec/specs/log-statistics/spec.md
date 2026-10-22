# log-statistics Specification

## Purpose

Define the scoped log statistics used by mobile dashboards: a submission overview, a daily submission trend, and the list of users who have not submitted today.

## Requirements

### Requirement: Provide a scoped statistics overview

The system SHALL expose `GET /api/stats/overview` and compute, within the caller's data scope, the expected number of log authors, the number of authors who submitted today, the number of authors who did not, and the submission rate as a percentage. Employees SHALL be scoped to themselves, team leaders to their team, department managers to their department, and the founder to the whole company; administrators SHALL be excluded from expected counts.

#### Scenario: Team overview counts only the team

- **WHEN** a team leader with one subordinate who submitted and one who did not calls `GET /api/stats/overview`
- **THEN** the response reports `expected=2`, `submitted=1`, `unsubmitted=1`, and `rate=50.0`

#### Scenario: Role without scope still gets a valid response

- **WHEN** an employee calls `GET /api/stats/overview`
- **THEN** the response reflects only that employee's submission state

### Requirement: Provide a daily submission trend

The system SHALL expose `GET /api/stats/trend?days=N` and return one point per day for the last `N` local dates, ordered from oldest to newest, where each point contains the date and the number of submitted logs in the caller's scope. `N` SHALL default to 7 and MUST be between 1 and 30.

#### Scenario: Trend ends with today

- **WHEN** a client calls `GET /api/stats/trend` without `days`
- **THEN** exactly 7 points are returned and the last point's date is today

#### Scenario: Invalid range

- **WHEN** a client calls `GET /api/stats/trend?days=0` or `days=31`
- **THEN** the request fails with HTTP 400 and business code `40001`

### Requirement: List users who have not submitted today

The system SHALL expose `GET /api/stats/unsubmitted` and return active, non-administrator users in the caller's scope who have no `SUBMITTED` log for today, including `id`, `username`, and `realName`.

#### Scenario: Unsubmitted subordinate is listed

- **WHEN** a team leader calls `GET /api/stats/unsubmitted` and one subordinate has no submitted log today
- **THEN** the response contains exactly that subordinate with their `realName`

#### Scenario: Submitted users are excluded

- **WHEN** every user in scope has submitted today
- **THEN** the response contains an empty `items` array and `total` equals 0
