## Why

The mobile client on `feat/pandora-task-workflow-v1.9` has moved beyond the backend contract: it now depends on progress history, completion percentages and notes, subordinate task views, dispatch approval/change workflows, richer task badges, and the V1.11 home/company presentation. Several repository methods already call endpoints that are absent or only partially implemented in the Spring Boot service. The backend must be brought to the same contract before mobile release and cloud rollout so the client does not silently lose data or bypass authorization.

## What Changes

- Extend task APIs for progress updates with percentage and notes, chronological history, subordinate read-only history, unread/issue state, and assignment detail needed by the new mobile screens.
- Add server-side dispatch request lifecycle: pending creation, approved publication, edit requests, withdrawal/deletion requests, and authorized request history; keep pending work out of received-task results.
- Add company-wide recipient/member queries and enforce caller-scoped visibility for received tasks, task maps, subordinate summaries, and published-task details.
- Complete account password reset/request/change endpoints used by mobile and preserve refresh-token/session behavior.
- Specify an authenticated, per-user daily-items API for a later optional cloud synchronization step; the V1.11 client remains device-local unless the product owner explicitly approves synchronization and the client is adapted.
- Align response envelopes, pagination, status values, validation, and error codes with the mobile repository contract; add migration, contract, authorization, and regression tests.

## Capabilities

### New Capabilities

- `task-progress-history`: Percentage/note progress updates and permission-scoped chronological history.
- `task-dispatch-approvals`: Pending dispatch, edit, withdrawal, and deletion approval workflows.
- `daily-items-sync`: Authenticated CRUD for per-user daily items, isolated from logs and company tasks.

### Modified Capabilities

- `task-management`: Update mobile task-board visibility, progress, subordinate views, dispatch lifecycle, and pagination contracts.
- `task-presentation`: Align task-map/company/home data semantics and badge-supporting fields with V1.9/V1.11 screens.
- `authentication`: Add the password reset/request/change flows and ensure the mobile session contract remains complete.

## Impact

- Spring Boot controllers, DTOs, services, authorization checks, error codes, and PostgreSQL migrations.
- Mobile-facing endpoints under `/api/tasks`, `/api/account`, `/api/auth`, `/api/daily-items`, `/api/task-map`, and company content endpoints.
- Contract, migration, authorization, and mobile-backend integration tests; Docker/CI validation before cloud deployment.
- Existing logs and task data must remain readable and migration-safe. Daily items must never alter work-log, company-task, approval, calendar, or employee-statistics records.
