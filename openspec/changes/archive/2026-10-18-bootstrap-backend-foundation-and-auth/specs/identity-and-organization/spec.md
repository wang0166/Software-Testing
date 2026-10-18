## ADDED Requirements

### Requirement: Enforce organization constraints in the database schema

The database schema SHALL enforce single-founder, single-department-manager, and single-team-leader uniqueness with partial unique indexes, SHALL enforce role-organization alignment with a check constraint, and SHALL restrict deletion of an organization that still has members or children.

#### Scenario: Duplicate organization leader is blocked by the database

- **WHEN** two rows would assign the same company a founder, the same department a manager, or the same team a leader
- **THEN** the partial unique index rejects the second write

#### Scenario: Invalid role-organization combination is blocked

- **WHEN** a user row has an employee or team leader without department and team, a department manager with a team, or a founder or administrator with any organization membership
- **THEN** the check constraint rejects the row

#### Scenario: Organization deletion is restricted

- **WHEN** a department or team that still has members or child organizations is deleted
- **THEN** the foreign key restriction rejects the deletion

#### Scenario: Cross-table team leader consistency remains a service rule

- **WHEN** a team leader references a team whose leader is another user or whose department differs from the user's department
- **THEN** the service layer rejects the write, because this cross-table rule cannot be expressed by a single-table check constraint
