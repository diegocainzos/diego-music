# ci-pipeline Specification

## Purpose
TBD - created by archiving change ci-github-actions. Update Purpose after archive.

## Requirements

### Requirement: Component checks on change
The system SHALL run each component's existing validation automatically on pull requests and on pushes to `main`, only when files of that component (or its workflow) change.

#### Scenario: Resolver change runs resolver tests
- **WHEN** a commit touching `ResolverService/` or `app/` is pushed to `main` or proposed in a pull request
- **THEN** the resolver suite runs through `scripts/validate-resolver.sh` on a Linux runner

#### Scenario: Web change runs web tests and build
- **WHEN** a commit touching `web/` is pushed or proposed
- **THEN** `npm ci`, `npm test` and `npm run build` run in `web/` on a Linux runner

#### Scenario: Android change runs unit tests and debug build
- **WHEN** a commit touching `android/` is pushed or proposed
- **THEN** `:app:testDebugUnitTest` and `:app:assembleDebug` run on a Linux runner with JDK 17

#### Scenario: Apple change runs macOS tests and iOS build
- **WHEN** a commit touching the Swift sources, tests, `project.yml`, `Config/` or the Xcode project is pushed or proposed
- **THEN** the macOS test suite and the iOS Simulator build-for-testing run on a macOS runner without code signing

#### Scenario: Unrelated change skips other components
- **WHEN** a commit only touches `web/`
- **THEN** the resolver, Android and Apple workflows do not run

#### Scenario: Only the Apple workflow uses macOS
- **WHEN** the workflows are inspected
- **THEN** only the Apple workflow runs on a macOS runner

### Requirement: Hardened workflows
Every workflow MUST grant only read access to repository contents, pin every third-party action to a full commit SHA, bound every job with a timeout, and cancel an in-progress run of the same workflow and ref when a newer one starts.

#### Scenario: Read-only token
- **WHEN** any workflow runs
- **THEN** its token has `contents: read` and no write permission

#### Scenario: Actions pinned by SHA
- **WHEN** any step uses an action
- **THEN** the reference is a 40-character commit SHA, not a tag or branch

#### Scenario: Jobs time out
- **WHEN** any job hangs
- **THEN** it is cancelled after its declared timeout of at most 30 minutes

#### Scenario: Superseded runs are cancelled
- **WHEN** a new commit is pushed to the same ref while a run is in progress
- **THEN** the older run of that workflow is cancelled

#### Scenario: No secrets reach CI checks
- **WHEN** any CI workflow runs
- **THEN** it does not reference repository secrets

### Requirement: Automated dependency updates
The system SHALL propose weekly dependency update pull requests for GitHub Actions, the resolver's pip requirements, the web's npm packages and the Android Gradle build.

#### Scenario: Weekly update PRs per ecosystem
- **WHEN** Dependabot configuration is inspected
- **THEN** it declares weekly updates for `github-actions` at `/`, `pip` at `/ResolverService`, `npm` at `/web` and `gradle` at `/android`

### Requirement: Secret leak protection
The repository MUST have secret scanning and push protection enabled so that pushes containing known credential formats are blocked.

#### Scenario: Push protection active
- **WHEN** the repository security settings are queried
- **THEN** secret scanning and secret scanning push protection are both `enabled`
