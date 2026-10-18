## Why

`documents/产品需求文档.md` now defines task distribution, independent per-recipient progress and review, personal tasks, company priority content, and task-facing pages, but the top-level, API, technical, and milestone documents still primarily describe the log-only baseline. Aligning those documents now gives implementation and QA one consistent source for task architecture, contracts, data ownership, and delivery scope without disturbing existing log requirements.

## What Changes

- Extend the top-level design with task modules, data relationships, permission boundaries, workflows, and task API groups.
- Add backend API contracts for task dispatch, recipient-specific execution/review, self-created tasks, and the two company display modules.
- Extend technical design with task persistence, state transitions, authorization, mobile page integration, read-only data-map/calendar data, and test coverage.
- Update milestones and sprint deliverables to include task implementation and verification while retaining the existing schedule baseline unless an explicit replanning decision is made.
- Preserve all existing log, feedback, statistics, authorization, and cutoff requirements; do not implement application code in this documentation-alignment change.

## Capabilities

### New Capabilities

- `task-management`: Direct-report task dispatch, recipient-isolated progress and review, and private self-created tasks.
- `task-presentation`: Task-facing mobile views, calendar indicators, and read-only task data map behavior.
- `company-priority-content`: Separate company display content maintained by the administrator or founder, outside ordinary task records.

### Modified Capabilities

None. The task behavior is being recorded as new OpenSpec capabilities; existing log requirements remain unchanged.

## Impact

- Updates `documents/顶层设计文档.md`, `documents/后端接口文档.md`, `documents/技术设计文档.md`, and `documents/项目计划与里程碑.md` against `documents/产品需求文档.md`.
- Adds OpenSpec specs and change artifacts under `openspec/changes/align-design-docs-with-task-requirements/`.
- No runtime code, database migration, or deployed API changes are included in this documentation change.
