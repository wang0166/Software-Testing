## ADDED Requirements

### Requirement: Provide a runnable backend scaffold

The backend SHALL be a Maven Spring Boot application organized into the layered packages defined by the technical design, and SHALL start successfully against a configured PostgreSQL instance with no manual code changes.

#### Scenario: Application starts with the configured database

- **WHEN** the backend is started with the documented environment variables and a reachable PostgreSQL database
- **THEN** it starts successfully, exposes the `/api` prefix, and reports a healthy status

#### Scenario: Layered packages are present

- **WHEN** the source tree is inspected
- **THEN** common, config, security, controller, service, mapper, entity, dto, job, and audit packages exist as defined by the technical design

### Requirement: Return a unified API response and map errors consistently

Every API response SHALL use the unified `code`/`message`/`data` structure, and business or validation failures SHALL return the documented business codes with the correct HTTP status instead of framework default errors.

#### Scenario: Successful response uses the unified structure

- **WHEN** any controller returns a successful result
- **THEN** the response body contains `code`, `message`, and `data`, with `code` equal to `0`

#### Scenario: Validation failure uses a documented code

- **WHEN** a request fails parameter validation
- **THEN** the response uses HTTP 400 and business code `40001` with an actionable message

#### Scenario: Unauthenticated request is rejected

- **WHEN** a protected endpoint is called without a valid access token
- **THEN** the response uses HTTP 401 and business code `40102`

### Requirement: Manage schema and seed data with versioned migrations

The database schema and seed data SHALL be created exclusively through versioned migrations, so that an empty database reaches the latest schema in one run and repeated startup does not reapply applied versions.

#### Scenario: Empty database reaches the latest schema

- **WHEN** the application starts against an empty database
- **THEN** all migrations apply in order and the schema includes organization, log, task, and configuration tables

#### Scenario: Seed data is present after migration

- **WHEN** migrations complete
- **THEN** the five roles, the documented permission codes (including `task:dispatch`, `task:execute`, `task:self`, `content:read`, `company-matter:manage`, `company-task:manage`), role-permission mappings, and system configuration defaults exist

#### Scenario: Repeated startup does not reapply migrations

- **WHEN** the application restarts against an already migrated database
- **THEN** no migration is applied twice and startup succeeds

### Requirement: Provide contract samples for client development

The repository SHALL include request/response samples and an executable contract test baseline for the authentication, task, company display content, data map, and calendar APIs, so that client teams can develop against mocks before those APIs are implemented.

#### Scenario: Client teams can use the samples

- **WHEN** a client developer opens the contract sample location
- **THEN** documented request and response examples exist for authentication and the planned task, company display content, data map, and calendar APIs

#### Scenario: Contract test baseline runs

- **WHEN** the backend test suite is executed
- **THEN** the authentication contract tests run and pass as part of the build
