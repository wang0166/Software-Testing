## ADDED Requirements

### Requirement: Backend work follows project milestones
Backend delivery SHALL be planned against the dates and outcomes in `documents/项目计划与里程碑.md`, covering contract and schema preparation, authentication and organization management, log lifecycle and cutoff, statistics and comments, integration and deployment, and final verification.

#### Scenario: Sprint work is scheduled
- **WHEN** a backend milestone task is added to the working checklist
- **THEN** it identifies a verifiable outcome and maps to the corresponding project sprint or milestone

### Requirement: Backend work is verifiable
Each backend checklist item SHALL have an observable completion condition such as a migration, endpoint, automated test result, contract example, deployment artifact, or recorded review outcome. API contract tests SHALL cover authorization boundaries and business-rule edge cases.

#### Scenario: Backend task is marked complete
- **WHEN** a backend checklist item is checked off
- **THEN** its stated verification evidence is available for review

#### Scenario: Release verification
- **WHEN** final backend acceptance is performed
- **THEN** authentication, log lifecycle, cutoff handling, role-scoped visibility, comment privacy, statistics, admin read-only behavior, performance targets, and deployment readiness have recorded results
