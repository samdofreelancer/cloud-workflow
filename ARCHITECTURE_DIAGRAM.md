# Architecture Diagram

## Workflow Organization

```
┌──────────────────────────────────────────────────────────────────┐
│  money-keeper/.github/workflows/backend-test-quality.yml         │
│  (THIN ORCHESTRATION - only 200 lines)                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Jobs (delegates all logic to actions):                          │
│  ├── prepare                                                    │
│  │   └── calls: detect-changes action                          │
│  │                                                             │
│  ├── compile                                                  │
│  │   └── calls: backend-compile action                        │
│  │                                                             │
│  ├─┬─ unit-test              (PARALLEL)                        │
│  │ └── calls: backend-unit-test action                        │
│  │                                                             │
│  ├─┬─ integration-test       (PARALLEL)                        │
│  │ └── calls: backend-integration-test action                 │
│  │                                                             │
│  ├── publish                                                  │
│  │   └── calls: publish-test-results action                   │
│  │                                                             │
│  ├── scan-quality                                             │
│  │   └── calls: quality-scan action                           │
│  │       └── runs: sonar_scan.py script                       │
│  │                                                             │
│  └── verify-quality                                           │
│      └── calls: verify-quality-gate action                    │
│          └── runs: verify_quality_gates.py script             │
│                                                               │
└──────────────────────────────────────────────────────────────────┘
                            ↓ delegates to
┌──────────────────────────────────────────────────────────────────┐
│  cloud-workflow/.github/actions/                                 │
│  (COMPOSITE ACTION IMPLEMENTATIONS - wraps all details)          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✅ detect-changes/action.yml                                   │
│     ├── Git change detection                                    │
│     └── Outputs: has-changes, sha-short                         │
│                                                                  │
│  ✅ backend-compile/action.yml                                  │
│     ├── Maven clean compile                                     │
│     ├── Cache Maven repository                                  │
│     └── Upload artifacts                                        │
│                                                                  │
│  ✅ backend-unit-test/action.yml                                │
│     ├── Maven test -Psmall-test                                │
│     ├── JaCoCo coverage collection                             │
│     └── Upload surefire reports                                │
│                                                                  │
│  ✅ backend-integration-test/action.yml                         │
│     ├── Start Oracle service                                    │
│     ├── Flyway migrations                                       │
│     ├── Maven verify -Pmedium-test                             │
│     ├── JaCoCo coverage collection                             │
│     └── Upload failsafe reports                                │
│                                                                  │
│  ✅ publish-test-results/action.yml                             │
│     ├── Aggregate all test artifacts                           │
│     ├── Create GitHub checks                                    │
│     └── Upload final JaCoCo report                             │
│                                                                  │
│  ✅ quality-scan/action.yml                                     │
│     ├── Download artifacts                                      │
│     ├── Invoke sonar_scan.py                                    │
│     └── Output quality gate status                              │
│                                                                  │
│  ✅ verify-quality-gate/action.yml                              │
│     ├── Invoke verify_quality_gates.py                         │
│     └── Final verification result                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                            ↓ executes
┌──────────────────────────────────────────────────────────────────┐
│  cloud-workflow/scripts/                                         │
│  (PYTHON BUSINESS LOGIC - production-ready scripts)             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✅ verify_quality_gates.py (used by verify-quality-gate)       │
│     • Aggregates test results                                   │
│     • Validates quality gates                                   │
│     • Exit code: 0=passed, 1=failed                             │
│                                                                  │
│  ✅ sonar_scan.py (used by quality-scan)                        │
│     • Checks SonarQube credentials                              │
│     • Merges JaCoCo coverage reports                            │
│     • Adds GitHub PR context                                    │
│     • Graceful fallback if disabled                             │
│     • Outputs status via GITHUB_OUTPUT                          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Security: SHA Pinning Strategy

```
Old (UNSAFE):
  - uses: actions/checkout@v4  ❌ Tag is mutable
  - uses: actions/upload@v4    ❌ Can be changed after release

New (SECURE):
  - uses: actions/checkout@e2f20c305c34d93f5c5edf45df8f7ef2d4bcc075  ✅ SHA is immutable
  - uses: actions/upload@834a144ee995460fba8ed112a2fc961b36a5ec5d    ✅ Git hash cannot change
```

## Data Flow

```
┌─────────────────────┐
│   Git Event         │
│ (push/PR/dispatch)  │
└──────────┬──────────┘
           ↓
    ┌─────────────────────┐
    │  Detect Changes     │
    │  (prepare job)      │
    └──────────┬──────────┘
               ↓
        ┌──────────────────┐
        │  Compile Code    │
        │  (compile job)   │
        └──────────┬───────┘
               ┌───┴───┐
               ↓       ↓
         ┌─────────┐ ┌──────────────┐
         │ Unit    │ │ Integration  │
         │ Tests   │ │ Tests        │
         │ (w/ JC) │ │ (w/ JC)      │
         └────┬────┘ └──────┬───────┘
              └───────┬─────┘
                      ↓
         ┌────────────────────────┐
         │  Publish Test Results  │
         │  + Coverage Reports    │
         └────────────┬───────────┘
                      ↓
         ┌────────────────────────┐
         │  SonarQube Analysis    │
         │  (Quality Gate Check)  │
         └────────────┬───────────┘
                      ↓
         ┌────────────────────────┐
         │  Verify Quality Gate   │
         │  (Final Aggregation)   │
         └────────────┬───────────┘
                      ↓
            ┌─────────────────────┐
            │  ✅ or ❌ Status   │
            │  Posted as Check    │
            └─────────────────────┘
```

## Execution Timeline

```
Timeline:          prepare  compile  unit  integration  publish  scan  verify
                      |       |       |         |         |       |      |
Speed:              ~5s     ~30s    ~20s      ~30s       ~5s    ~15s   ~5s
                      |       |       |         |         |       |      |
Dependency:         START    |       |         |         |       |      |
                            /         |         |         |       |      |
                          /           |_________|_________|       |      |
                        /                       |                 |      |
                      /                         |                 |      |
                    /                           |                 |      |
                  /                             |                 |      |
                /                               |_________________|      |
              /                                          |                |
            START                                        |                |
                                                         |________________|
                                                                |
                                                              DONE

Total: ~110s (1m50s) when all changes detected
       ~5s when no changes (early exit after prepare)
```

## Action Usage Pattern

```yaml
# Simple to use in workflow:
steps:
  - uses: ./cloud-workflow/.github/actions/backend-compile
    with:
      backend-dir: ./backend
      sha-short: ${{ needs.prepare.outputs.sha-short }}

# All complexity hidden in the action YAML:
# - Maven caching
# - Docker containers
# - Artifact management
# - Error handling
```

## Security Layers

```
Layer 1: GitHub Secrets
  └─ ORACLE_PASSWORD_SECRET (action inputs)
  └─ SONAR_HOST_URL, SONAR_LOGIN (action inputs)

Layer 2: SHA-Pinned Actions
  └─ No version drift possible
  └─ Git commit immutability guarantees

Layer 3: Minimal Permissions
  └─ Per-job: contents:read, checks:write only
  └─ No overprivileged workflows

Layer 4: Script Validation
  └─ Python scripts validate inputs
  └─ Graceful fallback on missing config
  └─ Explicit error exit codes
```

## Benefits Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                        BEFORE (MONOLITHIC)                      │
├─────────────────────────────────────────────────────────────────┤
│ workflow.yml (500+ lines)                                       │
│ ├── Maven logic mixed in YAML ❌                                 │
│ ├── Python inline scripts ❌                                     │
│ ├── Hard to maintain ❌                                          │
│ └── Version tagged actions ❌                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        AFTER (MODULAR)                          │
├─────────────────────────────────────────────────────────────────┤
│ workflow.yml (200 lines, clear structure) ✅                    │
│                                                                  │
│ cloud-workflow/.github/actions/ (7 focused actions) ✅           │
│ └─ Each action has single responsibility                       │
│ └─ SHA-pinned for security ✅                                    │
│ └─ Easy to version and test ✅                                   │
│                                                                  │
│ cloud-workflow/scripts/ (2 business logic scripts) ✅            │
│ └─ Testable Python code ✅                                       │
│ └─ Single point of update ✅                                     │
│ └─ Reusable across jobs ✅                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

**Architecture**: money-keeper (workflow) → cloud-workflow (actions) → cloud-workflow (scripts)  
**Security**: SHA pinning, minimal permissions, secret isolation  
**Maintainability**: Single responsibility, clear boundaries, testable code
