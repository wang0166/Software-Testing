## Why

The project plan makes the backend the owner of the REST contract, business rules, authorization filters, and scheduled processing, but those decisions are spread across product and technical documents. A consolidated contract and backend-owned milestone checklist give mobile, web, QA, and backend one reviewable delivery baseline.

## What Changes

- Document the backend REST API contract, including authentication, organization/user administration, logs, comments, statistics, configuration, audits, common responses, and authorization rules.
- Define testable backend behavior for API consistency, role-based data visibility, immutable submitted logs, cutoff processing, and admin read-only log access.
- Break the backend responsibilities in the project milestone plan into a verifiable checklist through final acceptance.

## Capabilities

### New Capabilities
- `backend-api-contract`: Stable REST behavior, request/response conventions, and authorization expectations for backend consumers.
- `backend-delivery-plan`: Backend implementation and verification work mapped to project milestones and sprints.

### Modified Capabilities
- None.

## Impact

- Adds `documents/后端接口文档.md` and root `tasks.md` as team-facing project artifacts.
- Adds OpenSpec change artifacts under `openspec/changes/backend-api-contract-and-workplan/`.
- No application code or runtime behavior changes in this planning change.
