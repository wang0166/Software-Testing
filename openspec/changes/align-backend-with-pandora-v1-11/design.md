## Context

The mobile repository now exposes a larger `PandoraRepository` contract than the current Spring Boot implementation. Existing task tables support basic dispatch, receipt, progress, invitations, and review, but not durable progress events or approval requests. V1.11 also introduces private daily items, while the current client stores them only in `shared_preferences`. Authorization is organization- and assignment-sensitive, and the deployment branch uses Flyway migrations and contract tests.

## Goals / Non-Goals

**Goals:**

- Provide stable, versioned API contracts for every mobile operation that requires server state.
- Preserve strict sender/assignee/subordinate visibility and prevent pending tasks from becoming received tasks.
- Store progress history and daily items transactionally with indexes suitable for mobile pagination and month queries.
- Keep response envelopes, status transitions, and errors compatible with existing mobile parsing.

**Non-Goals:**

- Rebuild the Flutter UI or replace its local daily-item storage in this change.
- Add push notifications, file attachments, or cross-company task sharing.
- Change existing log semantics or expose administrator-only data to mobile users.

## Decisions

1. **Extend the current `/api` contract rather than introduce a parallel version.** Existing mobile code already uses `/api/tasks`, `/api/auth`, and `/api/account`; additive endpoints and fields minimize rollout risk. Breaking status changes require explicit migration and compatibility tests.
2. **Represent approval workflows as first-class records.** Add dispatch request/change-request tables with requester, target task, action, payload, reviewer, status, timestamps, and unique pending constraints. A request is not a live task until approved; withdrawal is idempotent.
3. **Represent progress events separately from the assignment snapshot.** Keep current execution/review state on `task_assignments`, append immutable progress updates with percent, note, actor, and timestamp, and expose history only after the service verifies assignment or reporting-line access.
4. **Use current-user context for all ownership filters.** No endpoint accepts a user id to select the caller's own records. Subordinate endpoints accept a target user only after checking the caller's organization hierarchy and the assignment's ownership.
5. **Add daily items as an isolated table.** `daily_items` belongs to one user and has date, title, note, completed, and timestamps. Month reads use a bounded `YYYY-MM` range; CRUD derives owner from authentication. It never joins logs, tasks, calendar aggregation, or statistics.
6. **Use Flyway and contract tests as the compatibility boundary.** Migrations are additive and rollback is performed by deploying the previous image plus a forward-compatible schema; tests cover old records, authorization, pagination, and exact response shapes.

## Risks / Trade-offs

- [Risk] Existing mobile builds expect legacy status-only progress. → Keep the legacy PATCH endpoint, add the richer progress-update endpoint, and test both.
- [Risk] Approval payloads can become stale or replayed. → Enforce one pending request per target/action, optimistic version checks, and idempotent withdraw/review operations.
- [Risk] Subordinate queries may leak cross-team data. → Centralize organization-scope predicates and add negative authorization tests for every route.
- [Risk] Daily-item synchronization conflicts with device-local edits. → Treat server sync as opt-in/additive initially and document last-write-wins only after the mobile client sends stable ids and timestamps.

## Migration Plan

1. Add Flyway tables/indexes and DTO/service contracts without changing existing task rows.
2. Deploy backend and run migration/contract suites against existing data.
3. Enable mobile server-backed calls behind the client capability check; retain local daily items as fallback.
4. Roll back application images if needed; leave additive tables in place for forward compatibility.

## Open Questions

- Which role/permission is authorized to approve dispatch creation, edit, and deletion requests?
- Should daily-item sync be enabled for the first cloud release or remain behind a feature flag?
- What retention period and maximum note length should progress history use?
