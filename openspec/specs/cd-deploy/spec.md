# cd-deploy Specification

## Purpose
TBD - created by archiving change cd-vps-deploy. Update Purpose after archive.

## Requirements

### Requirement: Deploy after green CI
The system SHALL deploy a commit on `main` to the VPS only when every backend and web CI workflow run for that commit has completed successfully, and SHALL allow a manual deploy of the current `main`.

#### Scenario: All CI green triggers deploy
- **GIVEN** a commit on `main` whose `resolver` and `web` runs (those that exist for it) all concluded `success`
- **WHEN** the last of those runs completes
- **THEN** the deploy job runs for that commit SHA

#### Scenario: Failed CI blocks deploy
- **WHEN** a `resolver` or `web` run for the commit concludes with anything other than `success`
- **THEN** no deploy happens for that commit

#### Scenario: Sibling CI still running defers deploy
- **GIVEN** a commit with both `resolver` and `web` runs
- **WHEN** one completes while the other is still in progress
- **THEN** that deploy attempt exits without deploying, and the deploy happens when the other run completes green

#### Scenario: Manual deploy
- **WHEN** the deploy workflow is dispatched manually
- **THEN** it deploys the current head of `main`

#### Scenario: Deploys never overlap or get cancelled
- **WHEN** two deploys are triggered close together
- **THEN** the second waits for the first and neither is cancelled

### Requirement: Safe deploy on the server
The deploy script on the VPS MUST accept only a full 40-character commit SHA, back up the database before changing anything, move `main` forward only by fast-forward, rebuild the services, verify health, and roll back to the previous commit if the health check fails.

#### Scenario: Invalid input rejected
- **WHEN** the script receives anything other than a 40-character lowercase hex SHA
- **THEN** it exits non-zero without fetching, backing up or touching containers

#### Scenario: Already deployed is a no-op
- **WHEN** the requested SHA is already the deployed commit or one of its ancestors
- **THEN** the script exits successfully without backup or rebuild

#### Scenario: Non fast-forward rejected
- **WHEN** the requested SHA is not a descendant of the deployed commit
- **THEN** the script exits non-zero and the deployed commit and containers are unchanged

#### Scenario: Backup precedes update
- **WHEN** a new SHA is deployed
- **THEN** a timestamped copy of the SQLite database is stored under the backups directory before the checkout changes, and only the 14 most recent backups are kept

#### Scenario: Backup failure aborts deploy
- **WHEN** the database backup fails
- **THEN** the script exits non-zero and the deployed commit and containers are unchanged

#### Scenario: Healthy deploy
- **WHEN** the services are rebuilt and the health endpoint answers successfully within the timeout
- **THEN** the checkout is at the requested SHA and the script exits successfully

#### Scenario: Unhealthy deploy rolls back
- **WHEN** the health endpoint does not answer successfully within the timeout
- **THEN** the checkout returns to the previous commit, the services are rebuilt from it, and the script exits non-zero

### Requirement: Restricted deploy credential
The deploy workflow MUST reach the VPS only with a dedicated SSH key that the server restricts to running the deploy script, with the host key pinned, and MUST read its secrets only from the `production` environment.

#### Scenario: Key cannot run arbitrary commands
- **WHEN** someone uses the deploy key to request any command
- **THEN** the server runs only the deploy script, which rejects the request unless it is a valid SHA

#### Scenario: Host key pinned
- **WHEN** the workflow connects
- **THEN** it verifies the server against a stored known_hosts entry and never accepts unknown host keys

#### Scenario: Hardened deploy workflow
- **WHEN** the deploy workflow is inspected
- **THEN** it uses the `production` environment, pins actions by SHA, has a timeout, grants only `contents: read` and `actions: read`, and does not cancel in-progress runs
