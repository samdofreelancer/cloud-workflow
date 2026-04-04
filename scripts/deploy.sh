#!/bin/bash

# Kubernetes Deployment Helper Script for Money Keeper
# Usage: ./deploy.sh [environment] [image_tag]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHART_PATH="./helm-charts/money-keeper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="${1:-dev}"
IMAGE_TAG="${2:-$(date +%Y%m%d-%H%M%S)}"
NAMESPACE="money-keeper-${ENVIRONMENT}"
RELEASE_NAME="money-keeper"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    echo -e "${RED}✗ Invalid environment: $ENVIRONMENT${NC}"
    echo "  Valid options: dev, staging, production"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Money Keeper Kubernetes Deployment${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Environment:    ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Namespace:      ${YELLOW}${NAMESPACE}${NC}"
echo -e "Image Tag:      ${YELLOW}${IMAGE_TAG}${NC}"
echo -e "Chart Path:     ${YELLOW}${CHART_PATH}${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..60})${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Step 1: Validate prerequisites
print_section "Validating Prerequisites"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl."
    exit 1
fi
print_success "kubectl found: $(kubectl version --client --short)"

if ! command -v helm &> /dev/null; then
    print_error "helm not found. Please install helm."
    exit 1
fi
print_success "helm found: $(helm version --short)"

if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
    print_error "Chart not found at $CHART_PATH"
    exit 1
fi
print_success "Helm chart found"

# Step 2: Validate cluster access
print_section "Validating Cluster Access"

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to cluster: $(kubectl cluster-info | head -1)"

CURRENT_CONTEXT=$(kubectl config current-context)
print_success "Current context: $CURRENT_CONTEXT"

# Step 3: Create namespace
print_section "Creating Namespace"

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warning "Namespace '$NAMESPACE' already exists"
else
    kubectl create namespace "$NAMESPACE"
    print_success "Namespace '$NAMESPACE' created"
fi

# Step 4: Setup secrets
print_section "Setting up Secrets"

# Check if kubeconfig has necessary credentials
if [ -z "${DB_HOST:-}" ]; then
    print_warning "DB_HOST environment variable not set, using default"
    DB_HOST="${DB_HOST:-localhost}"
fi

if [ -z "${DB_PORT:-}" ]; then
    print_warning "DB_PORT environment variable not set, using default (5432)"
    DB_PORT="${DB_PORT:-5432}"
fi

if [ -z "${DB_NAME:-}" ]; then
    print_warning "DB_NAME environment variable not set, using default"
    DB_NAME="${DB_NAME:-money_keeper}"
fi

if [ -z "${DB_USER:-}" ]; then
    print_error "DB_USER environment variable not set"
    exit 1
fi

if [ -z "${DB_PASSWORD:-}" ]; then
    print_error "DB_PASSWORD environment variable not set"
    exit 1
fi

# Create ConfigMap
kubectl create configmap money-keeper-backend-config \
    --from-literal=DATABASE_HOST="$DB_HOST" \
    --from-literal=DATABASE_PORT="$DB_PORT" \
    --from-literal=DATABASE_NAME="$DB_NAME" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
print_success "ConfigMap created/updated"

# Create Secret
kubectl create secret generic money-keeper-db-secret \
    --from-literal=DATABASE_USER="$DB_USER" \
    --from-literal=DATABASE_PASSWORD="$DB_PASSWORD" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
print_success "Database secret created/updated"

# Step 5: Create image pull secret
print_section "Setting up Image Pull Secrets"

if [ -z "${GITHUB_USERNAME:-}" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
    print_warning "GITHUB_USERNAME or GITHUB_TOKEN not set, skipping image pull secret"
else
    kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username="$GITHUB_USERNAME" \
        --docker-password="$GITHUB_TOKEN" \
        --docker-email="${GITHUB_EMAIL:-noreply@github.com}" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    print_success "Image pull secret created/updated"
fi

# Step 6: Prepare Helm values
print_section "Preparing Helm Values"

VALUES_FILE="$CHART_PATH/values-${ENVIRONMENT}.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    print_warning "Environment-specific values file not found: $VALUES_FILE"
    print_warning "Using default values"
    VALUES_FILE="$CHART_PATH/values.yaml"
fi

# Create temporary values override
TEMP_VALUES=$(mktemp)
cat > "$TEMP_VALUES" <<EOF
environment: $ENVIRONMENT

backend:
  image:
    tag: "$IMAGE_TAG"
    repository: "ghcr.io/samdofreelancer/money-keeper-backend"

frontend:
  image:
    tag: "$IMAGE_TAG"
    repository: "ghcr.io/samdofreelancer/money-keeper-frontend"

serviceAccount:
  create: true
  name: money-keeper
EOF

print_success "Helm values prepared"

# Step 7: Validate Helm chart
print_section "Validating Helm Chart"

helm lint "$CHART_PATH" || {
    print_error "Helm chart validation failed"
    rm -f "$TEMP_VALUES"
    exit 1
}
print_success "Helm chart validation passed"

# Step 8: Helm template preview
print_section "Chart Template Preview"

MANIFEST_COUNT=$(helm template "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$VALUES_FILE" \
    -f "$TEMP_VALUES" | grep -c "kind:" || true)
print_success "Templates will generate $MANIFEST_COUNT resources"

# Step 9: Deploy using Helm
print_section "Deploying with Helm"

helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$VALUES_FILE" \
    -f "$TEMP_VALUES" \
    --timeout 10m \
    --wait \
    --atomic \
    --create-namespace || {
    print_error "Helm deployment failed"
    rm -f "$TEMP_VALUES"
    exit 1
}
print_success "Helm deployment completed"

# Cleanup
rm -f "$TEMP_VALUES"

# Step 10: Wait for rollout
print_section "Waiting for Rollout"

for deployment in backend frontend; do
    DEPLOY_NAME="money-keeper-${deployment}"
    echo "  Waiting for $DEPLOY_NAME..."
    kubectl rollout status deployment/"$DEPLOY_NAME" \
        -n "$NAMESPACE" \
        --timeout=5m || {
        print_warning "$DEPLOY_NAME did not rollout successfully"
    }
done
print_success "Rollout complete"

# Step 11: Verify deployment
print_section "Verifying Deployment"

echo ""
echo "Deployments:"
kubectl get deployments -n "$NAMESPACE"

echo ""
echo "Pods:"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "Services:"
kubectl get services -n "$NAMESPACE"

echo ""
echo "Ingress:"
kubectl get ingress -n "$NAMESPACE" || print_warning "No ingress found"

# Step 12: Display access information
print_section "Access Information"

BACKEND_SERVICE="money-keeper-backend-service"
FRONTEND_SERVICE="money-keeper-frontend-service"

echo ""
echo "Backend Service:"
echo "  kubectl port-forward -n $NAMESPACE svc/$BACKEND_SERVICE 8080:8080"
echo ""
echo "Frontend Service:"
echo "  kubectl port-forward -n $NAMESPACE svc/$FRONTEND_SERVICE 3000:80"
echo ""
echo "View Logs:"
echo "  kubectl logs -n $NAMESPACE -f deployment/money-keeper-backend"
echo "  kubectl logs -n $NAMESPACE -f deployment/money-keeper-frontend"
echo ""

# Final summary
print_section "Deployment Summary"
echo ""
echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
echo ""
echo "Environment:    $ENVIRONMENT"
echo "Namespace:      $NAMESPACE"
echo "Image Tag:      $IMAGE_TAG"
echo ""
echo "Next steps:"
echo "  1. Verify services are running: kubectl get pods -n $NAMESPACE"
echo "  2. Check logs: kubectl logs -n $NAMESPACE -f deployment/money-keeper-backend"
echo "  3. Port-forward to test locally: kubectl port-forward -n $NAMESPACE svc/money-keeper-frontend-service 3000:80"
