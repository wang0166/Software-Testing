## ADDED Requirements

### Requirement: Provide isolated authenticated daily items
The system SHALL provide `GET /api/daily-items?month=YYYY-MM`, `POST /api/daily-items`, `PATCH /api/daily-items/{id}`, and `DELETE /api/daily-items/{id}`. Each item SHALL contain an owner-derived user id, date, title, note, completed flag, and timestamps. The owner SHALL be taken from authentication; request bodies MUST NOT select another user.

#### Scenario: Read a month
- **WHEN** an authenticated user requests a valid month
- **THEN** the server returns only that user's items whose dates fall within that calendar month

#### Scenario: Update own item
- **WHEN** the owner changes an item's date, title, note, or completed flag
- **THEN** the server persists the change and returns the updated item

#### Scenario: Cross-user access is denied
- **WHEN** a user guesses another user's item id
- **THEN** the server returns HTTP 404 or 403 without revealing the item

### Requirement: Keep daily items independent
Daily-item writes SHALL NOT create or modify logs, company tasks, task approvals, calendar task marks, or employee statistics.

#### Scenario: Complete daily item
- **WHEN** a user marks a daily item complete
- **THEN** only the daily-item record changes and task/log counts remain unchanged
