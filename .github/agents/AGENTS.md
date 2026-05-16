# Cloud-Workflow Agents

This directory contains custom agent configurations for the Cloud-Workflow repository.

## Available Agents

### cicd-cloud-workflow
**Name**: `cicd-cloud-workflow`

**Purpose**: Senior DevOps/CI-CD architect specialized in implementing GitHub Actions workflows following the CICD_DESIGN rules from Money Keeper project.

**When to Use**:
- Implementing new GitHub Actions workflows
- Updating Helm charts or infrastructure
- Optimizing pipeline performance
- Adding new deployment environments
- Debugging CI/CD failures
- Designing deployment strategies
- Creating infrastructure automation

**Key Responsibilities**:
- Design and implement reusable GitHub Actions workflows
- Manage Helm charts and environment configurations
- Orchestrate multi-environment deployments
- Ensure deployment safety (blue-green, canary)
- Optimize performance and security
- Maintain infrastructure-as-code

**Expertise Areas**:
- GitHub Actions workflow design
- Kubernetes (GKE) orchestration
- Helm chart templating
- Docker image building
- Multi-environment management
- Deployment strategies
- Infrastructure security

**File**: [cicd-cloud-workflow.agent.md](cicd-cloud-workflow.agent.md)

---

## How to Use Custom Agents

1. **In Copilot Chat**, use the agent name in your prompt:
   ```
   @cicd-cloud-workflow: Create a new deployment workflow for the staging environment
   ```

2. **Or invoke via subagent**:
   ```
   runSubagent(agentName: "cicd-cloud-workflow", prompt: "your task here")
   ```

---

## Related Documentation

- [CI/CD Implementation Guidelines](../docs/CICD_IMPLEMENTATION.md)
- [CICD_DESIGN Rules](../../money-keeper/docs/CICD_DESIGN.md)
- [Helm Chart Guidelines](../docs/HELM_GUIDELINES.md)

