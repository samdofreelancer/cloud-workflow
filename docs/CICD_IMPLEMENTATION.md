# CI/CD Implementation Guidelines

## Overview

This document provides guidelines for implementing GitHub Actions workflows and infrastructure for Money Keeper following the **CICD_DESIGN rules**.

**Key Principle**: Workflows live in **money-keeper**, infrastructure details live in **cloud-workflow**.

---

## Repository Division

### Money Keeper (`.github/workflows/`)
**Purpose**: Define CI/CD pipeline execution workflows

**Contains**:
- Main orchestrator workflow
- Reusable workflows (build, deploy, test, cleanup)
- Workflow linting and validation
- Composite actions (lightweight)

**Responsibility**: Define WHAT and WHEN

### Cloud-Workflow
**Purpose**: Detailed infrastructure implementation

**Contains**:
- Helm charts (`helm-charts/money-keeper/`)
- Deployment scripts (`scripts/`)
- Kubernetes manifests (`k8s/`)
- Infrastructure documentation

**Responsibility**: Define HOW and WHERE

---

## CICD_DESIGN Rules

### 1. Pipeline Architecture

```
Code Push/Merge → Lint → Build Images → Deploy Backend → Deploy Frontend → Run E2E → Cleanup
```

**Jobs**:
1. `lint-workflows` - Validate workflow YAML with actionlint
2. `build-images` - Build Docker images for backend & frontend
3. `deploy-backend` - Start Oracle, run migrations, deploy backend with ngrok
4. `deploy-frontend` - Deploy frontend to GKE with Helm
5. `run-e2e` - Execute E2E tests (Playwright + Cucumber)
6. `cleanup` - Remove resources (always runs)

### 2. Reusable Workflow Pattern

Each major step should be a reusable workflow:

```yaml
# .github/workflows/build-images.yml
name: Build Docker Images
on:
  workflow_call:
    inputs:
      branch:
        required: true
        type: string
    outputs:
      backend-image:
        value: ${{ jobs.build.outputs.backend-image }}
      frontend-image:
        value: ${{ jobs.build.outputs.frontend-image }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      backend-image: ghcr.io/${{ github.repository }}/backend:${{ github.sha }}
      frontend-image: ghcr.io/${{ github.repository }}/frontend:${{ github.sha }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.branch }}
      # Build and push images...
```

### 3. Environment Variables & Secrets

**GitHub Variables** (Settings > Variables):
```
GKE_CLUSTER=my-cluster
GKE_ZONE=us-central1-a
```

**GitHub Secrets** (Settings > Secrets):
```
GCP_SA_KEY=<JSON service account key>
ORACLE_PASSWORD_SECRET=<password>
NGROK_AUTH_TOKEN=<token>
```

### 4. Job Dependencies

Use `needs:` to enforce sequence:

```yaml
build-images:
  needs: lint-workflows

deploy-backend:
  needs: build-images

deploy-frontend:
  needs: [build-images, deploy-backend]

run-e2e:
  needs: [deploy-backend, deploy-frontend]

cleanup:
  needs: run-e2e
  if: always()  # Always run
```

### 5. Concurrency Control

Cancel previous runs when new push occurs:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

---

## Workflow Implementation Checklist

### Build Images Workflow
- [ ] Uses `docker/build-push-action@v5` with buildx
- [ ] Builds both backend and frontend
- [ ] Pushes to GHCR
- [ ] Outputs image references for downstream jobs
- [ ] Uses Docker layer caching

### Deploy Backend Workflow
- [ ] Checks out code
- [ ] Starts Oracle container
- [ ] Runs Flyway migrations (Oracle or H2)
- [ ] Builds and starts backend container
- [ ] Exposes backend via ngrok tunnel
- [ ] Outputs backend URL
- [ ] Handles startup timeouts

**Example Backend Deployment**:
```bash
# Start Oracle
docker run -d --name oracle \
  -e ORACLE_PASSWORD=${{ secrets.ORACLE_PASSWORD_SECRET }} \
  -p 1522:1521 \
  gvenzl/oracle-xe:latest

# Wait for Oracle
timeout 300 bash -c 'until sqlplus ...; do sleep 10; done'

# Run Flyway
mvn flyway:migrate -Dflyway.locations=filesystem:backend/src/main/resources/db/migration/oracle

# Start Backend
docker run -d --name backend \
  -e SPRING_DATASOURCE_URL=jdbc:oracle:thin:@localhost:1522/xe \
  -e SPRING_DATASOURCE_PASSWORD=${{ secrets.ORACLE_PASSWORD_SECRET }} \
  -p 8080:8080 \
  ghcr.io/${{ github.repository }}/backend:${{ github.sha }}

# Expose via ngrok
ngrok http 8080 --auth-token ${{ secrets.NGROK_AUTH_TOKEN }}
```

### Deploy Frontend Workflow
- [ ] Checks out code
- [ ] Authenticates with GCP (via `setup-gcp` action)
- [ ] Sets up kubectl context
- [ ] Installs Helm
- [ ] Renders Helm chart with image and backend URL
- [ ] Applies manifests to GKE
- [ ] Patches service to LoadBalancer
- [ ] Waits for load balancer IP
- [ ] Outputs frontend URL

**Example Frontend Deployment**:
```bash
# Setup GCP
gcloud auth activate-service-account --key-file=${{ secrets.GCP_SA_KEY }}
gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} \
  --zone ${{ vars.GKE_ZONE }}

# Deploy with Helm
helm template money-keeper cloud-workflow/helm-charts/money-keeper \
  -f cloud-workflow/helm-charts/money-keeper/values-dev.yaml \
  --set backend.image=${{ needs.build-images.outputs.backend-image }} \
  --set frontend.image=${{ needs.build-images.outputs.frontend-image }} \
  --set api.baseUrl=${{ needs.deploy-backend.outputs.backend-url }} \
  | kubectl apply -f -

# Expose LoadBalancer
kubectl patch svc frontend -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP
kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Run E2E Workflow
- [ ] Checks out code
- [ ] Sets up Node.js
- [ ] Caches npm dependencies
- [ ] Installs Playwright browsers (cached)
- [ ] Sets BASE_URL and API_BASE_URL environment variables
- [ ] Runs Playwright tests
- [ ] Uploads test report as artifact
- [ ] Uploads HTML report

**Example E2E Execution**:
```bash
# Setup
npm ci

# Cache Playwright browsers
npx playwright install

# Run tests
BASE_URL=${{ needs.deploy-frontend.outputs.frontend-url }} \
API_BASE_URL=${{ needs.deploy-backend.outputs.backend-url }} \
npm run test:e2e

# Upload reports
artifact upload ./playwright-report
```

### Cleanup Workflow
- [ ] Authenticates with GCP
- [ ] Deletes frontend deployment from GKE
- [ ] Stops ngrok tunnel
- [ ] Stops backend container
- [ ] Stops Oracle container
- [ ] Cleans Docker resources
- [ ] Runs even on failure (`if: always()`)

---

## Helm Chart Guidelines

### Chart Structure

```
helm-charts/money-keeper/
  Chart.yaml                    # Chart metadata
  values.yaml                   # Default values
  values-dev.yaml               # Dev overrides
  values-staging.yaml           # Staging overrides
  values-production.yaml        # Production overrides
  templates/
    _helpers.tpl                # Helper templates
    backend-deployment.yaml     # Backend Deployment
    backend-service.yaml        # Backend Service
    backend-hpa.yaml            # Backend HPA
    backend-pdb.yaml            # Backend PDB
    frontend-deployment.yaml    # Frontend Deployment
    frontend-service.yaml       # Frontend Service
    frontend-hpa.yaml           # Frontend HPA
    frontend-pdb.yaml           # Frontend PDB
    configmap.yaml              # ConfigMap
    secret.yaml                 # Secret
    serviceaccount.yaml         # ServiceAccount
    ingress.yaml                # Ingress (if applicable)
```

### Values Management

**values.yaml** (defaults):
```yaml
backend:
  image: ghcr.io/org/backend:latest
  replicas: 1
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

frontend:
  image: ghcr.io/org/frontend:latest
  replicas: 1
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "250m"
```

**values-dev.yaml** (development overrides):
```yaml
backend:
  replicas: 1
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "250m"

frontend:
  replicas: 1
  resources:
    requests:
      memory: "128Mi"
      cpu: "50m"
    limits:
      memory: "256Mi"
      cpu: "100m"

enableIngress: false
```

**values-production.yaml** (production overrides):
```yaml
backend:
  replicas: 3
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

frontend:
  replicas: 3
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

enableIngress: true
enableAutoscaling: true
```

### Template Best Practices

1. **Use conditional rendering**:
```yaml
{{- if .Values.enableIngress }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "money-keeper.fullname" . }}
spec:
  {{- omitted for brevity }}
{{- end }}
```

2. **Use helper functions**:
```yaml
{{- define "money-keeper.labels" -}}
helm.sh/chart: {{ include "money-keeper.chart" . }}
{{ include "money-keeper.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

3. **Validate with**: `helm lint` and `helm template`

---

## Performance Optimization

### Caching Strategy

1. **Docker Layer Caching**:
```yaml
- uses: docker/build-push-action@v5
  with:
    context: backend/
    cache-from: type=registry,ref=ghcr.io/${{ github.repository }}/backend:buildcache
    cache-to: type=registry,ref=ghcr.io/${{ github.repository }}/backend:buildcache,mode=max
```

2. **Node Modules Caching**:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '18'
    cache: 'npm'
    cache-dependency-path: e2e/package-lock.json
```

3. **Playwright Browser Caching**:
```yaml
- uses: actions/cache@v3
  with:
    path: ~/.cache/ms-playwright
    key: ${{ runner.os }}-playwright-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-playwright-
```

---

## Security Hardening

1. **Use GitHub Secrets**:
   - Never hardcode credentials in workflows
   - Use `${{ secrets.SECRET_NAME }}`

2. **Minimal Permissions**:
   - Service accounts should have minimal required permissions
   - Use RBAC for Kubernetes

3. **Image Security**:
   - Scan images for vulnerabilities
   - Use image signing/verification
   - Pin base image versions

4. **Credential Management**:
   - Rotate secrets regularly
   - Use short-lived tokens where possible
   - Audit credential access

---

## Troubleshooting

### Common Issues

1. **Workflow Fails at Lint**:
   - Run `actionlint` locally: `actionlint .github/workflows/*.yml`
   - Check syntax in workflow files

2. **Image Build Fails**:
   - Check Dockerfile syntax
   - Verify base image availability
   - Check build context

3. **GKE Deployment Fails**:
   - Verify GCP service account permissions
   - Check GKE cluster accessibility
   - Verify Helm chart values

4. **E2E Tests Timeout**:
   - Increase test timeout
   - Check frontend/backend URLs
   - Review test logs

5. **Cleanup Doesn't Run**:
   - Ensure `if: always()` is set
   - Check job dependencies

---

## Local Testing

Use `act` to test workflows locally:

```bash
# Install act
brew install act

# Run a specific workflow
act -j build-images -s GITHUB_TOKEN=$YOUR_TOKEN

# Run all workflows
act -s GITHUB_TOKEN=$YOUR_TOKEN
```

---

## References

- [CICD_DESIGN](../../money-keeper/docs/CICD_DESIGN.md)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

