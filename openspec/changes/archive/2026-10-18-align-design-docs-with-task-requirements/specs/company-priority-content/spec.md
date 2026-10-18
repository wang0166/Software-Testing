## ADDED Requirements

### Requirement: Separate publication ownership by content type
The system SHALL provide independent company important-matters and company important-tasks display modules. Only the administrator SHALL publish and edit important matters through Web, and only the founder SHALL publish and edit important tasks through Android. Other users SHALL have read-only access to displayed content.

#### Scenario: Administrator publishes important matters
- **WHEN** an administrator publishes company important matters through Web
- **THEN** the published content is available read-only to other users in the mind-map company-matters module

#### Scenario: Founder updates important tasks
- **WHEN** the founder edits company important tasks through Android
- **THEN** other users see the updated display content but cannot edit it

#### Scenario: Wrong publisher attempts edit
- **WHEN** a founder attempts to edit administrator-owned company important matters or an administrator attempts to edit founder-owned important tasks
- **THEN** the system rejects the unauthorized edit

### Requirement: Exclude company display content from task data
Company important matters and company important tasks SHALL NOT create ordinary task or recipient execution records, participate in task distribution or task statistics, or appear in the data map or calendar task marks.

#### Scenario: Company important task is published
- **WHEN** the founder publishes an item in company important tasks
- **THEN** no recipient assignment is created and the item is absent from received tasks, task statistics, data map, and calendar task marks
