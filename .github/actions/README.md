# Backend Tests & Quality Workflow Architecture

## Overview

The workflow architecture follows a **thin YAML, logic-in-actions, scripts-in-cloud** pattern:

```
money-keeper workflow 
    ↓ (calls)
cloud-workflow composite actions
    ↓ (wrap)
cloud-workflow Python scripts
```

## Repository Division

### money-keeper/.github/workflows/backend-test-quality.yml
- **Responsibility**: Thin orchestration workflow
- **Contains**: Job definitions, triggers, concurrency control
- **Does NOT contain**: Implementation logic or step details
- **Only changes**: Job names, order, inputs/outputs

### cloud-workflow/.github/actions/
Composite actions wrap all implementation details:

- `detect-changes/` - Change detection with Git
- `backend-compile/` - Maven compilation
- `backend-unit-test/` - Unit test execution with JaCoCo
- `backend-integration-test/` - Integration tests with Oracle service
- `publish-test-results/` - Test report publishing
- `quality-scan/` - SonarQube analysis
- `verify-quality-gate/` - Quality verification

### cloud-workflow/scripts/
Python scripts contain business logic:

- `verify_quality_gates.py` - Aggregates and validates quality checks
- `sonar_scan.py` - SonarQube scanning with credential handling

## Security: SHA Pinning

All action references use **commit SHA** instead of version tags:

```yaml
- uses: actions/checkout@e2f20c305c34d93f5c5edf45df8f7ef2d4bcc075  # v4
```

Commit SHAs are:
- ✅ Immutable (cannot be changed retroactively)
- ✅ Auditable (tracks exact code version)
- ✅ Tamper-proof (Git integrity guarantees)

## Workflow Sequence

```
prepare (detect changes)
    ↓
compile (Maven build)
    ↓
[unit-test, integration-test] (parallel)
    ↓
publish (aggregate reports)
    ↓
scan-quality (SonarQube)
    ↓
verify-quality (final gate)
```

## Job Dependencies

- **prepare**: Standalone (detects if tests should run)
- **compile**: Depends on prepare
- **unit-test, integration-test**: Parallel, depend on compile
- **publish**: Depends on unit-test, integration-test
- **scan-quality**: Depends on unit-test, integration-test
- **verify-quality**: Depends on unit-test, integration-test, scan-quality

## Conditional Execution

Skips tests when no backend changes:

```yaml
if: needs.prepare.outputs.has-changes == 'true'
```

## Artifact Management

| Artifact | Retention | Purpose |
|----------|-----------|---------|
| build-* | 1 day | Maven compiled classes |
| coverage-unit-* | 5 days | JaCoCo unit test coverage |
| coverage-integration-* | 5 days | JaCoCo integration coverage |
| tests-unit-* | 5 days | Surefire unit test reports |
| tests-integration-* | 5 days | Failsafe integration reports |
| jacoco-report-final | 30 days | Aggregated coverage report |

## Trigger Events

Workflow runs on:

- `workflow_dispatch` - Manual trigger
- `push` to develop/master with backend changes
- `pull_request` to develop/master with backend changes

## Required Secrets

Configure in money-keeper repository:

| Secret | Purpose |
|--------|---------|
| `ORACLE_PASSWORD_SECRET` | Database password for integration tests |
| `SONAR_HOST_URL` | Cloud SonarQube instance URL |
| `SONAR_LOGIN` | SonarQube authentication token |

## Extending the Workflow

### Add a new composite action:

1. Create `cloud-workflow/.github/actions/my-action/action.yml`
2. Use SHA-pinned GitHub Actions inside
3. Wrap step logic in the action
4. Call from money-keeper workflow

### Add a new job:

1. Update `money-keeper/.github/workflows/backend-test-quality.yml`
2. Reference the composite action (path: `./cloud-workflow/.github/actions/...`)
3. Define inputs/outputs as needed
4. Set proper `needs:` dependencies

## Debugging

### View action implementation:
```bash
cat cloud-workflow/.github/actions/backend-compile/action.yml
```

### Run workflow locally:
```bash
# Install act (GitHub Actions local runner)
brew install act

# Run specific job
act push -j compile
```

### Check artifact contents:
Artifacts are downloaded in `publish` job and available in GitHub UI.

## Benefits of This Architecture

✅ **Separation of Concerns**: Workflow = orchestration, actions = implementation  
✅ **Security**: SHA-pinned dependencies, no version drift  
✅ **Maintainability**: Logic changes in one place (actions/scripts)  
✅ **Reusability**: Actions can be used by other workflows  
✅ **Testability**: Python scripts can be unit tested  
✅ **Auditability**: Clear responsibility boundaries  
