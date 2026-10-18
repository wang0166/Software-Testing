# identity-and-organization Specification

## Purpose

Define single-founder, single-department-manager, and single-team-leader organization uniqueness, consistency between user role and organization membership, and administrator-only account provisioning without self-registration.

## Requirements

### Requirement: Enforce single organization leader

The system SHALL allow at most one founder per company, at most one department manager per department, and at most one team leader per team. A team MUST NOT have multiple leaders.

#### Scenario: Second founder is rejected

- **WHEN** an administrator attempts to assign a second founder to the company
- **THEN** the system rejects the assignment and keeps the existing founder unchanged

#### Scenario: Second department manager is rejected

- **WHEN** an administrator attempts to assign a second manager to a department that already has one
- **THEN** the system rejects the assignment with a conflict response

#### Scenario: Second team leader is rejected

- **WHEN** an administrator attempts to assign a second leader to a team that already has one
- **THEN** the system rejects the assignment and the team keeps its existing leader

### Requirement: Align user role with organization membership

Every user SHALL have exactly one role. Employees and team leaders SHALL belong to exactly one team and its department. A department manager SHALL belong to one department and MUST NOT belong to a team. Founders and administrators MUST NOT belong to any department or team. A team leader's team MUST be the team whose leader is that user, and that team's department MUST equal the user's department.

#### Scenario: Employee without a team is rejected

- **WHEN** an administrator creates or edits an employee or team leader without both a department and a team
- **THEN** the system rejects the request as invalid organization membership

#### Scenario: Department manager assigned to a team is rejected

- **WHEN** an administrator assigns a team to a department manager
- **THEN** the system rejects the request

#### Scenario: Founder or administrator assigned to an organization is rejected

- **WHEN** an administrator assigns a department or team to a founder or administrator
- **THEN** the system rejects the request

#### Scenario: Team leader does not match the team

- **WHEN** a user is assigned the team-leader role but is not the leader of the referenced team, or the team belongs to a different department
- **THEN** the system rejects the request and leaves the user and team unchanged

### Requirement: Provision accounts only through the administrator

All accounts SHALL be created by the administrator through the Web management console. The system SHALL NOT provide self-registration through any client. Users SHALL authenticate on Android with administrator-issued credentials, and the administrator SHALL be able to disable or enable an account.

#### Scenario: No self-registration entry exists

- **WHEN** an unauthenticated user looks for account registration on Android or Web
- **THEN** no registration endpoint or registration UI is available

#### Scenario: Disabled account cannot log in

- **WHEN** a user whose account has been disabled by the administrator attempts to log in
- **THEN** the system rejects the login until the administrator enables the account

#### Scenario: Administrator creates a founder account

- **WHEN** the administrator creates the founder account through the Web console
- **THEN** the account is created with the founder role and no department or team membership

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
