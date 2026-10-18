# delivery-planning Specification

## Purpose

Define the shared 16-Sprint and M1-M9 schedule baseline used by the top-level design and project plan, and schedule organization-constraint and usability verification.

## Requirements

### Requirement: Maintain a single schedule baseline

The top-level design and the project plan SHALL use the same schedule baseline: Sprint 1 through Sprint 16, milestones M1 through M9, and the period from 2026-09-18 to 2027-01-07. The top-level design SHALL NOT retain a conflicting Sprint 0/Sprint 1/Sprint 2/Sprint 3/Final division.

#### Scenario: Sprint overview matches the project plan

- **WHEN** the top-level design sprint overview is compared with the project plan
- **THEN** both use the same sprint count, milestone identifiers, and start/end dates

#### Scenario: Detailed tasks have one source

- **WHEN** a reader needs the detailed tasks for a sprint
- **THEN** the top-level design points to the project plan as the single detailed source instead of duplicating a divergent schedule

### Requirement: Schedule organization and permission verification

The project plan SHALL schedule verification of organization-leader uniqueness and role-organization alignment in the organization and user-management stage, and SHALL include database-constraint and API-contract coverage for the same rules in the integration and API test stage.

#### Scenario: Organization constraints tested in Sprint 3

- **WHEN** Sprint 3 organization and user management is completed
- **THEN** its test tasks include duplicate founder, duplicate department manager, duplicate team leader, and invalid role-organization membership cases

#### Scenario: Constraints covered by integration and API tests

- **WHEN** Sprint 12 integration and API testing is completed
- **THEN** the test scope includes the user role-organization constraint and the organization-leader uniqueness rules

### Requirement: Schedule usability verification

The M8 deliverables and Sprint 15 tasks SHALL include usability testing for first-log completion time, error guidance, page depth, and common Android resolutions.

#### Scenario: M8 includes usability deliverables

- **WHEN** M8 is delivered
- **THEN** its deliverables include a usability test record in addition to end-to-end, authorization, security, performance, and regression results
