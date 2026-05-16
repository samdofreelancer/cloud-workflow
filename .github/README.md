# GitHub Cloud-Workflow Configuration

This directory contains GitHub-specific configuration including workflows and custom agents for the Cloud-Workflow DevOps repository.

## Directory Structure

```
.github/
├── agents/                  # Custom Copilot agents
│   ├── cicd-cloud-workflow.agent.md  # CI/CD implementation agent
│   └── AGENTS.md                     # Agent index and documentation
├── workflows/               # GitHub Actions workflows
│   ├── eslint.yml          # ESLint validation
│   ├── manual-build.yml    # Manual build trigger
│   └── manual-deploy.yml   # Manual deployment trigger
└── chatmodes/              # Custom Copilot chat modes (future)
```

## Custom Agents

### cicd-cloud-workflow Agent
**Name**: `cicd-cloud-workflow`

Specialized agent for implementing CI/CD pipelines and infrastructure automation.

**Use when**:
- Creating GitHub Actions workflows
- Managing Helm charts and Kubernetes manifests
- Designing deployment strategies
- Optimizing pipeline performance
- Setting up multi-environment deployments

**Key Features**:
- Follows CICD_DESIGN rules from Money Keeper
- Implements reusable workflow patterns
- Manages Helm chart templates
- Designs deployment safety strategies
- Optimizes for performance and security

**Quick Start**:
```
@cicd-cloud-workflow: Help me create a GitHub Actions workflow for deploying to staging
```

See [agents/AGENTS.md](agents/AGENTS.md) for full details.

## Workflows

### eslint.yml
Validates JavaScript/TypeScript code with ESLint.

**Trigger**: On push to main branches, PR

### manual-build.yml
Manually triggered workflow for building Docker images.

**Trigger**: Manual (`workflow_dispatch`)

### manual-deploy.yml
Manually triggered workflow for deploying applications.

**Trigger**: Manual (`workflow_dispatch`)

## Key Resources

- **Agents**: [agents/AGENTS.md](agents/AGENTS.md)
- **CI/CD Implementation**: [../docs/CICD_IMPLEMENTATION.md](../docs/CICD_IMPLEMENTATION.md)
- **Helm Guidelines**: [../docs/HELM_GUIDELINES.md](../docs/HELM_GUIDELINES.md)
- **Setup Guide**: [../docs/CI_CD_AGENT_SETUP.md](../docs/CI_CD_AGENT_SETUP.md)
- **CICD_DESIGN Rules**: [../../money-keeper/docs/CICD_DESIGN.md](../../money-keeper/docs/CICD_DESIGN.md)

## Architecture

### Repository Alignment

**Money Keeper** (Product):
- Application code
- Unit tests
- E2E test scenarios
- GitHub Actions workflows (in `.github/workflows/`)

**Cloud-Workflow** (DevOps):
- Helm charts
- Kubernetes manifests
- Deployment scripts
- Infrastructure-as-Code
- Custom agents for CI/CD

### CI/CD Pipeline Flow

```
Lint Workflows
    ↓
Build Images (Docker)
    ↓
Deploy Backend (with ngrok tunnel)
    ↓
Deploy Frontend (to GKE with Helm)
    ↓
Run E2E Tests (Playwright + Cucumber)
    ↓
Cleanup (always)
```

## Getting Started

1. **Understand CICD_DESIGN**
   - Read: [Money Keeper CICD_DESIGN](../../money-keeper/docs/CICD_DESIGN.md)

2. **Review Implementation Guidelines**
   - Read: [CICD_IMPLEMENTATION.md](../docs/CICD_IMPLEMENTATION.md)

3. **Learn Helm Best Practices**
   - Read: [HELM_GUIDELINES.md](../docs/HELM_GUIDELINES.md)

4. **Use the Custom Agent**
   - Reference: [CI_CD_AGENT_SETUP.md](../docs/CI_CD_AGENT_SETUP.md)
   - Invoke: `@cicd-cloud-workflow` in Copilot Chat

## Workflow Best Practices

### Job Structure
- Use `needs:` for dependencies
- Always run cleanup with `if: always()`
- Set appropriate timeouts
- Use reusable workflows

### Environment Configuration
- Use GitHub Variables for configuration
- Use GitHub Secrets for credentials
- Never hardcode sensitive data
- Support multiple environments (dev, staging, prod)

### Caching Strategy
- Cache Docker layers
- Cache npm dependencies
- Cache Playwright browsers
- Cache Helm templates

### Security
- Minimal permissions (least privilege)
- Use RBAC for Kubernetes
- Scan images for vulnerabilities
- Rotate secrets regularly
- Audit all deployments

## Helm Chart Management

### Chart Location
`helm-charts/money-keeper/`

### Environment Values
- `values.yaml` - Default/base
- `values-dev.yaml` - Development
- `values-staging.yaml` - Staging
- `values-production.yaml` - Production

### Deployment Command
```bash
helm template money-keeper helm-charts/money-keeper/ \
  -f helm-charts/money-keeper/values-dev.yaml \
  --set backend.image.tag=$VERSION \
  | kubectl apply -f -
```

## Troubleshooting

### Workflow Failures
1. Check workflow syntax: `actionlint .github/workflows/`
2. View logs in GitHub Actions tab
3. Test locally with `act`

### Helm Deployment Issues
1. Validate chart: `helm lint helm-charts/money-keeper/`
2. Dry-run: `helm template money-keeper helm-charts/money-keeper/`
3. Check values: `helm values money-keeper`

### GKE Access Issues
1. Verify GCP service account permissions
2. Check cluster credentials: `gcloud container clusters get-credentials`
3. Verify kubectl context: `kubectl config current-context`

## Common Commands

```bash
# Lint workflows
actionlint .github/workflows/

# Test workflow locally
act -j build-images

# Validate Helm chart
helm lint helm-charts/money-keeper/

# Template Helm chart
helm template money-keeper helm-charts/money-keeper/ -f helm-charts/money-keeper/values-dev.yaml

# Deploy with Helm
helm upgrade --install money-keeper helm-charts/money-keeper/ \
  -f helm-charts/money-keeper/values-dev.yaml \
  --namespace money-keeper-dev

# Check deployment status
kubectl get deployments -n money-keeper-dev
kubectl get pods -n money-keeper-dev
```

## Documentation

- **Overview**: This file
- **Agents**: [agents/AGENTS.md](agents/AGENTS.md)
- **Implementation Guide**: [../docs/CICD_IMPLEMENTATION.md](../docs/CICD_IMPLEMENTATION.md)
- **Helm Guidelines**: [../docs/HELM_GUIDELINES.md](../docs/HELM_GUIDELINES.md)
- **Agent Setup**: [../docs/CI_CD_AGENT_SETUP.md](../docs/CI_CD_AGENT_SETUP.md)

## Support

When you need help with CI/CD tasks:

```
@cicd-cloud-workflow: [Your task/question]
```

The agent will help you with:
- Workflow design and implementation
- Helm chart management
- Deployment strategies
- Infrastructure automation
- Performance optimization
- Security hardening

---

**Happy DevOps-ing!** 🚀

