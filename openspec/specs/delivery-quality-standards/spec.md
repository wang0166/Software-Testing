# delivery-quality-standards Specification

## Purpose

Define performance, critical-API success rate, usability, and Android resolution acceptance targets, together with the test coverage required to verify them.

## Requirements

### Requirement: Meet performance and availability targets

The system SHALL load ordinary pages within 3 seconds, return log lists within 2 seconds, generate statistics for up to 100 logs within 3 seconds, and keep the success rate of critical APIs at or above 99%.

#### Scenario: Performance verification records success rate

- **WHEN** performance testing is executed for the release candidate
- **THEN** the report records response times for ordinary pages, log lists, and statistics together with the critical-API success rate

#### Scenario: Critical API success rate below target

- **WHEN** the measured critical-API success rate is below 99%
- **THEN** the release does not pass performance acceptance until the issue is fixed and retested

### Requirement: Meet usability acceptance targets

A new user SHALL be able to complete the first log submission within 3 minutes. Error messages SHALL explain how to fix the problem. Primary mobile operations SHALL require no more than 3 page levels. Pages SHALL render correctly at common Android resolutions.

#### Scenario: First-time user submits a log

- **WHEN** a new user follows the Android log flow for the first time
- **THEN** the user can complete the first log submission within 3 minutes

#### Scenario: Validation error is shown

- **WHEN** a user submits invalid input
- **THEN** the error message states what is wrong and how to correct it

#### Scenario: Common Android resolution

- **WHEN** the app is opened on a device using a common Android resolution
- **THEN** the main pages and primary operations render without truncation or overlap

### Requirement: Verify quality targets in the test plan

The test plan SHALL include usability verification for first-log completion time, error guidance, page depth, and Android resolution coverage, and SHALL include the critical-API success-rate target in performance verification.

#### Scenario: Usability test is part of non-functional testing

- **WHEN** M8 non-functional testing is completed
- **THEN** the deliverables include a usability test record covering the first-log time limit, error guidance, page depth, and common Android resolutions

#### Scenario: Usability evidence is missing

- **WHEN** non-functional testing finishes without usability evidence
- **THEN** M8 is not considered complete
