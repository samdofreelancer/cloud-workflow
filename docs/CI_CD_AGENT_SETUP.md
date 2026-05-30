# Cloud-Workflow CI/CD Agent Setup Guide

## Quick Start

The **cicd-cloud-workflow** custom agent is now available in this repository. This agent specializes in implementing GitHub Actions workflows and managing infrastructure following the **CICD_DESIGN** rules from Money Keeper.

### Using the Agent

#### In GitHub Copilot Chat
When working on CI/CD tasks, invoke the agent in Copilot Chat:

```
@cicd-cloud-workflow: Create a new GitHub Actions workflow to deploy the backend to staging environment
```

Or ask for help with infrastructure:

```
@cicd-cloud-workflow: Update the Helm chart values for production environment with new resource limits
```

#### Agent Capabilities

The agent can help with:

**Workflow Implementation**
- Design new GitHub Actions workflows
- Create reusable workflows (build, deploy, test, cleanup)
- Implement job dependencies and orchestration
- Optimize workflow execution time
- Add security and error handling

**Helm Chart Management**
- Create/update Helm charts and templates
- Manage environment-specific values
- Template Kubernetes manifests
- Implement deployment strategies
- Configure resource management and autoscaling

**Infrastructure Automation**
- Design multi-environment deployments
- Create deployment scripts
- Implement deployment safety features (blue-green, canary)
- Configure Kubernetes resources
- Set up monitoring and observability

**Pipeline Optimization**
- Reduce workflow execution time
- Implement caching strategies
- Optimize Docker builds
- Improve test performance

**Security & Compliance**
- Implement secret management
- Configure RBAC and permissions
- Secure image builds and deployments
- Audit infrastructure changes

---

## Key Rules & Principles

All work follows the **CICD_DESIGN** rules defined in [Money Keeper CICD_DESIGN](../../money-keeper/docs/CICD_DESIGN.md):

### Repository Division
- **money-keeper/.github/workflows/**: Workflow definitions (WHAT)
- **cloud-workflow/**: Infrastructure implementation (HOW)

### Pipeline Flow
```
Lint → Build Images → Deploy Backend → Deploy Frontend → Run E2E → Cleanup
```

### Core Concepts
- **Modularity**: Reusable workflows for each major step
- **Environment Strategy**: Dev, staging, production with different configs
- **Deployment Safety**: Blue-green, canary, automated rollback
- **Performance**: Caching, parallel execution, optimization
- **Security**: Secrets management, RBAC, minimal permissions

---

## Common Tasks

### 1. Create a New Workflow

Ask the agent:
```
@cicd-cloud-workflow: Create a new workflow file "deploy-staging.yml" that:
- Builds Docker images for backend and frontend
- Deploys to GKE staging cluster
- Runs E2E tests
- Follows the CICD_DESIGN pattern
```

**What to expect**: The agent will:
- Generate the workflow YAML with proper structure
- Use reusable workflows pattern
- Include error handling and timeouts
- Add appropriate job dependencies
- Provide inline documentation

### 2. Update Helm Chart Values

Ask the agent:
```
@cicd-cloud-workflow: Update the Helm chart values-production.yaml to:
- Set backend replicas to 5
- Increase memory limits to 2Gi
- Enable autoscaling with maxReplicas: 10
- Configure pod disruption budget for 3 minimum available
```

**What to expect**: The agent will:
- Update the values file with new settings
- Maintain existing structure and comments
- Ensure valid YAML syntax
- Provide clear explanations of changes

### 3. Implement Blue-Green Deployment

Ask the agent:
```
@cicd-cloud-workflow: Design a blue-green deployment strategy using Helm:
- Deploy new version to "green" environment
- Verify health checks pass
- Switch traffic from blue to green
- Keep blue as rollback point
- Implement with script in scripts/deploy.sh
```

**What to expect**: The agent will:
- Create deployment script with blue-green logic
- Update Helm charts to support dual environments
- Implement health check verification
- Add traffic switching mechanism
- Document the entire process

### 4. Optimize Docker Build Performance

Ask the agent:
```
@cicd-cloud-workflow: Optimize the docker build workflow to:
- Implement layer caching
- Use buildx for multi-platform builds
- Cache Docker layers in registry
- Reduce build time from current
```

**What to expect**: The agent will:
- Update build-images.yml workflow
- Add buildx configuration
- Implement registry caching
- Provide performance improvement estimates
- Suggest additional optimizations

### 5. Configure Multi-Environment Deployment

Ask the agent:
```
@cicd-cloud-workflow: Set up deployment scripts that:
- Support dev, staging, and production environments
- Use different Helm values per environment
- Validate cluster credentials before deployment
- Include pre/post deployment checks
- Handle deployment failures with rollback
```

**What to expect**: The agent will:
- Create `scripts/deploy.sh` with environment logic
- Generate validation scripts
- Implement error handling and logging
- Set up pre-deployment checks
- Document environment setup

---

## Project Structure Overview

```
money-keeper/
├── .github/
│   ├── workflows/              # GitHub Actions workflows (agents here too)
│   │   ├── e2e-gke.yml         # Main orchestrator workflow
│   │   ├── build-images.yml    # Docker image building
│   │   ├── deploy-backend.yml  # Backend deployment
│   │   ├── deploy-frontend.yml # Frontend deployment to GKE
│   │   ├── run-e2e.yml         # E2E test execution
│   │   ├── cleanup.yml         # Resource cleanup
│   │   └── lint-workflows.yml  # Workflow validation
│   ├── agents/                 # Custom agent definitions
│   └── actions/                # Composite actions (if any)
└── docs/
    └── CICD_DESIGN.md          # CI/CD design rules (MUST READ)

cloud-workflow/
├── .github/
│   ├── agents/
│   │   ├── cicd-cloud-workflow.agent.md  # This agent
│   │   └── AGENTS.md                     # Agent index
│   └── workflows/              # Additional workflows (build/deploy)
├── helm-charts/
│   └── money-keeper/           # Helm chart for Money Keeper
│       ├── Chart.yaml
│       ├── values.yaml         # Default values
│       ├── values-dev.yaml     # Dev overrides
│       ├── values-staging.yaml # Staging overrides
│       ├── values-production.yaml # Production overrides
│       └── templates/          # Kubernetes manifests
├── k8s/                        # Kubernetes manifests (if not using Helm)
├── scripts/
│   ├── deploy.sh               # Main deployment script
│   ├── validate-cluster.sh     # Pre-deployment validation
│   └── ...                     # Other scripts
└── docs/
    ├── CICD_IMPLEMENTATION.md  # Implementation guidelines
    ├── HELM_GUIDELINES.md      # Helm chart guidelines
    └── ...                     # Other documentation
```

---

## Workflow Files Reference

### e2e-gke.yml (Main Orchestrator)
- **Purpose**: Orchestrates full CI/CD pipeline
- **Trigger**: Manual (`workflow_dispatch`)
- **Jobs**: lint → build → deploy-backend → deploy-frontend → run-e2e → cleanup

### build-images.yml (Reusable)
- **Purpose**: Build Docker images for backend and frontend
- **Inputs**: branch (optional)
- **Outputs**: backend-image, frontend-image
- **Actions**: Docker build-push with caching

### deploy-backend.yml (Reusable)
- **Purpose**: Deploy backend with Oracle database
- **Inputs**: backend-image
- **Outputs**: backend-url
- **Actions**: Start Oracle, run Flyway, expose via ngrok

### deploy-frontend.yml (Reusable)
- **Purpose**: Deploy frontend to GKE with Helm
- **Inputs**: frontend-image, backend-url
- **Outputs**: frontend-url
- **Actions**: GCP auth, Helm template, kubectl apply

### run-e2e.yml (Reusable)
- **Purpose**: Execute E2E tests
- **Inputs**: frontend-url, backend-url
- **Outputs**: test results, artifacts
- **Actions**: Install deps, run Playwright tests

### cleanup.yml (Reusable)
- **Purpose**: Clean up all deployed resources
- **Always runs**: Even if tests fail
- **Actions**: Delete K8s resources, stop containers

---

## Common Patterns

### Job Dependency Pattern
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ghcr.io/...
    steps:
      # build steps

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/workflows/deploy-images.yml
        with:
          image: ${{ needs.build.outputs.image }}

  test:
    needs: [build, deploy]
    runs-on: ubuntu-latest
    steps:
      # test steps

  cleanup:
    if: always()
    needs: test
    steps:
      # cleanup steps
```

### Environment Variables Pattern
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  GKE_CLUSTER: ${{ vars.GKE_CLUSTER }}
  GKE_ZONE: ${{ vars.GKE_ZONE }}

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      BASE_IMAGE: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
```

### Caching Pattern
```yaml
- uses: actions/cache@v3
  with:
    path: ~/.docker/buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: ${{ runner.os }}-buildx-

- uses: docker/build-push-action@v5
  with:
    cache-from: type=local,src=~/.docker/buildx-cache
    cache-to: type=local,dest=~/.docker/buildx-cache-new
```

### Error Handling Pattern
```yaml
- name: Deploy Backend
  id: deploy-backend
  run: |
    timeout 300 ./scripts/deploy-backend.sh || exit 1
    echo "backend-url=http://backend:8080" >> $GITHUB_OUTPUT

- name: Verify Deployment
  run: |
    health_check=$(curl -f http://localhost:8080/actuator/health || echo "failed")
    if [[ "$health_check" == "failed" ]]; then
      echo "Backend health check failed"
      exit 1
    fi
```

---

## Documentation Resources

**Must Read**:
- [CICD_DESIGN - Money Keeper](../../money-keeper/docs/CICD_DESIGN.md) - Core rules
- [CICD_IMPLEMENTATION.md](./CICD_IMPLEMENTATION.md) - Implementation guidelines
- [HELM_GUIDELINES.md](./HELM_GUIDELINES.md) - Helm chart best practices

**Reference**:
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Charts Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/)

---

## Testing Workflows Locally

Use `act` to test GitHub Actions workflows locally:

```bash
# Install act
brew install act  # macOS
choco install act # Windows

# List available jobs
act -l

# Run specific job
act -j build-images

# Run with secrets
act -s GITHUB_TOKEN=$YOUR_TOKEN -j build-images

# Run full workflow
act workflow_dispatch -s GITHUB_TOKEN=$YOUR_TOKEN
```

---

## When to Use This Agent

✅ **Use this agent when**:
- Creating or updating GitHub Actions workflows
- Managing Helm charts or Kubernetes manifests
- Designing deployment strategies
- Optimizing pipeline performance
- Implementing new environments (dev, staging, prod)
- Debugging CI/CD failures
- Setting up infrastructure automation
- Reviewing or improving CI/CD architecture

❌ **Don't use this agent when**:
- Implementing application features (use money-keeper agent)
- Writing backend code (use money-keeper agent)
- Writing frontend code (use money-keeper agent)
- Writing unit/integration tests (use money-keeper agent)

For those, use the [money-keeper](../../money-keeper/.github/agents/money-keeper.agent.md) agent instead.

---

## Support & Questions

When asking the agent for help:

1. **Be specific** about what you want to accomplish
2. **Reference CICD_DESIGN** if relevant
3. **Provide context** about the environment (dev/staging/prod)
4. **Include constraints** (performance, security, compliance)
5. **Ask for validation** of the generated code

Example:
```
@cicd-cloud-workflow: 
I need to add a new production environment deployment.
Requirements:
- Deploy to us-west-1 GKE cluster
- Backend should have 5 replicas
- Frontend should have 3 replicas
- Enable autoscaling (max 10 replicas)
- Include health checks and pod disruption budgets
- Update Helm charts with values-production.yaml
- Create deployment script in scripts/

Please validate with CICD_DESIGN rules.
```

---

## Next Steps

1. **Review CICD_DESIGN** to understand the core rules
2. **Explore existing workflows** in money-keeper/.github/workflows/
3. **Check Helm charts** in cloud-workflow/helm-charts/
4. **Read implementation guidelines** above
5. **Start with simple tasks** and gradually tackle complex ones
6. **Ask the agent for help** when you're unsure

---

**Happy CI/CD architecting!** 🚀

