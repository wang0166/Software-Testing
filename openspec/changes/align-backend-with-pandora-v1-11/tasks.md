## 1. Baseline and contracts

- [x] 1.1 Inventory every `PandoraRepository` endpoint on `feat/pandora-task-workflow-v1.9` and map it to the current Spring controller/service, DTO, permission, and error code.
- [ ] 1.2 Add contract fixtures for response envelopes, pagination, status values, completion percentage, latest progress, issue state, and unread state.
- [ ] 1.3 Define approval permissions and reviewer roles with product/operations owners; record the decision in the change design before implementation.

## 2. Database migrations and domain records

- [ ] 2.1 Add additive Flyway migration for progress-update events, dispatch requests/change requests, and daily items with owner/status constraints and indexes.
- [ ] 2.2 Add unique pending-request constraints and indexes for assignment history, month-scoped daily-item reads, and caller-scoped task queries.
- [ ] 2.3 Verify migrations against an existing V11 database and confirm existing tasks, assignments, logs, and refresh tokens remain readable.

## 3. Task progress and authorization

- [ ] 3.1 Add DTOs and controller routes for progress updates with percentage/note validation and the legacy status-only PATCH compatibility path.
- [ ] 3.2 Implement transactional progress-event persistence and assignment snapshot updates; reject changes during pending/approved review.
- [ ] 3.3 Implement assignee history and subordinate read-only history with centralized reporting-scope authorization.
- [ ] 3.4 Extend received-task, assignment-detail, task-map, and subordinate-summary responses with current progress, latest event, issue, unread, and stable ids.
- [ ] 3.5 Add negative authorization tests for unrelated users, senders attempting assignee updates, cross-team subordinates, and guessed assignment ids.

## 4. Dispatch approval lifecycle

- [ ] 4.1 Add pending dispatch creation/list/detail endpoints and validate direct recipients, dates, urgency, type, and duplicate assignees before persistence.
- [ ] 4.2 Implement approval/rejection transactions that publish assignments exactly once and keep pending/withdrawn proposals out of received tasks.
- [ ] 4.3 Implement pending proposal edit/withdrawal and published-task update/delete change requests with idempotency and optimistic version checks.
- [ ] 4.4 Add reviewer authorization, audit records, and contract tests for unauthorized review, duplicate requests, rejection, approval, and rollback-safe failures.

## 5. Account and daily items

- [ ] 5.1 Implement password reset request, authenticated change request/status, completion, rate limiting, audit, and session invalidation contracts.
- [ ] 5.2 Add daily-item DTO/controller/service CRUD with owner derived only from authentication and bounded month queries.
- [ ] 5.3 Add tests proving daily-item writes do not affect logs, company tasks, approvals, calendar marks, or statistics; keep the mobile local-storage fallback documented.

## 6. Verification and rollout

- [ ] 6.1 Run Maven unit, migration, authorization, and mobile-backend contract suites against the merged deployment branch.
- [ ] 6.2 Run web build, Docker Compose validation, and backend/web image builds using the same CI environment as `devops/docker`.
- [ ] 6.3 Update API/mobile integration documentation with endpoint examples, statuses, permissions, and rollout flags.
- [ ] 6.4 Stage the aligned commit on `devops/docker`, review CI artifacts, and only then authorize image publication and ECS deployment.
