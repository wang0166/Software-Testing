## Context

Pandora is a single-company work-log system with Flutter Android clients for employees and managers, and a React web console for system administrators. The product requirements establish the role hierarchy, immutable submitted logs, daily cutoff behavior, direct-manager-only comments, and role-scoped visibility. The technical design proposes Spring Boot, MyBatis, PostgreSQL, JWT access/refresh tokens, BCrypt, and Flyway. The project plan assigns API contracts, business rules, authorization, and scheduled jobs to the backend role.

This change captures planning and contract artifacts only. The repository currently has no existing OpenSpec capabilities to modify.

## Goals / Non-Goals

**Goals:**
- Make endpoint scope and common protocol conventions explicit enough for frontend mocks and API contract tests.
- Map backend work from Sprint 1 through Sprint 16, retaining dates and milestone outcomes from the project plan.
- Record unresolved contract decisions instead of silently inventing behavior.

**Non-Goals:**
- Implement controllers, services, schema migrations, scheduled jobs, or tests.
- Freeze low-level framework configuration or add API versioning beyond the source documents.
- Define the deferred AI analysis, notifications, offline entry, or export features.

## Decisions

- Use the technical design's `/api` route family and endpoint inventory as the baseline. The API document will consolidate this inventory while identifying ambiguities as open decisions.
- Use JSON and a uniform `{ code, message, data }` success/error envelope, with paginated list metadata documented where the existing design does not prescribe exact field names as a contract decision for review.
- Treat the server as authoritative for identity, role, organization scope, log date, deadline, and direct-manager relationships. Client-supplied filters never expand access.
- Keep `NOT_SUBMITTED` as a derived statistics state when no daily log exists, as specified in the design; do not introduce a persisted daily-status record.
- Put the detailed backend checklist at repository root `tasks.md` for practical team use and mirror the OpenSpec-tracked subset in this change's `tasks.md` so the change can be applied and tracked.
- Organize requirements into API contract and delivery plan capabilities, since they are independently reviewable outputs.

Alternatives considered:
- Keeping only the existing API section in the technical design would leave no focused, frontend-ready contract document.
- Replacing the project milestone plan would lose team-wide dates and non-backend responsibilities; the new checklist instead extracts backend ownership.

## Risks / Trade-offs

- The source technical design contains endpoint examples but does not settle every field name or status code. → The contract marks proposed conventions and explicit open questions for team agreement.
- Mirroring checklist items in two files can drift. → Root `tasks.md` is the working checklist; OpenSpec tasks track creation/review of the artifact and major delivery groups.
- Some admin CRUD route details are only grouped in the technical design. → The API document preserves that scope and flags exact method/soft-delete semantics for confirmation.

## Migration Plan

No runtime migration is required. Review the API contract with mobile, web, QA, and operations; update the shared contract before endpoint implementation if an open question is resolved differently. The backend checklist follows the existing Sprint dates and can be checked off as work completes.

## Open Questions

- Should refresh tokens be rotated on each refresh, and are they stored hashed and revocable per device/session?
- What are the exact permission codes and HTTP status mappings for all authorization failures?
- Should deleting departments/teams be hard delete or soft delete, and what is the required reassignment workflow?
- What exact pagination envelope, sort whitelist, and maximum page size do both clients expect?
- What are the accepted length limits for log content and comments?
- Is `isImportant` included in MVP despite being described as optional P1?
- Which roles can query comments on logs they can read if they are neither author nor direct manager? Current requirements say only author and direct manager.
