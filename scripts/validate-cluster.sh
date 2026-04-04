#!/bin/bash

# Kubernetes Cluster Validation Script
# Validates K8s cluster is ready for Money Keeper deployment

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Kubernetes Cluster Validation for Money Keeper${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..60})${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Track failures
FAILURES=0

print_header

# Check 1: kubectl
print_section "Checking kubectl"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+')
    print_success "kubectl found: $KUBECTL_VERSION"
else
    print_error "kubectl not found"
    FAILURES=$((FAILURES + 1))
fi

# Check 2: Helm
print_section "Checking Helm"
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+')
    print_success "Helm found: $HELM_VERSION"
else
    print_error "Helm not found"
    FAILURES=$((FAILURES + 1))
fi

# Check 3: Cluster connectivity
print_section "Checking Cluster Connectivity"
if kubectl cluster-info &> /dev/null; then
    CLUSTER_INFO=$(kubectl cluster-info | head -1)
    print_success "Connected to cluster"
    echo "  $CLUSTER_INFO"
else
    print_error "Cannot connect to cluster"
    FAILURES=$((FAILURES + 1))
    exit 1
fi

# Check 4: API Server
print_section "Checking API Server"
if kubectl api-resources &> /dev/null; then
    API_GROUPS=$(kubectl api-resources | wc -l)
    print_success "API Server responding ($API_GROUPS resource types available)"
else
    print_error "API Server not responding"
    FAILURES=$((FAILURES + 1))
fi

# Check 5: Cluster version
print_section "Checking Cluster Version"
K8S_VERSION=$(kubectl version --short | grep "Server" | grep -oP 'v\d+\.\d+\.\d+')
print_success "Kubernetes version: $K8S_VERSION"

MAJOR=$(echo "$K8S_VERSION" | cut -d. -f1)
MINOR=$(echo "$K8S_VERSION" | cut -d. -f2)

if [[ $MAJOR -gt 1 ]] || [[ $MAJOR -eq 1 && $MINOR -ge 24 ]]; then
    print_success "Kubernetes version meets minimum requirement (1.24+)"
else
    print_warning "Kubernetes version is older than 1.24, some features may not be available"
fi

# Check 6: Available nodes
print_section "Checking Nodes"
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)

if [[ $READY_NODES -gt 0 ]]; then
    print_success "Found $READY_NODES/$TOTAL_NODES ready nodes"
    kubectl get nodes --no-headers | awk '{print "  " $0}'
else
    print_error "No ready nodes found"
    FAILURES=$((FAILURES + 1))
fi

# Check 7: Node resources
print_section "Checking Node Resources"
if kubectl top nodes &> /dev/null; then
    kubectl top nodes --no-headers | while read line; do
        NODE=$(echo "$line" | awk '{print $1}')
        CPU=$(echo "$line" | awk '{print $2}')
        MEMORY=$(echo "$line" | awk '{print $3}')
        echo "  $NODE: CPU ${CPU}, Memory ${MEMORY}"
    done
    print_success "Node resources are available"
else
    print_warning "Cannot retrieve node metrics (Metrics Server may not be installed)"
fi

# Check 8: Ingress Controller
print_section "Checking Ingress Controller"
INGRESS_NS=$(kubectl get ingress --all-namespaces 2>/dev/null | grep -v "NAMESPACE" | head -1 | awk '{print $1}')
if kubectl get ingressclass &> /dev/null; then
    INGRESS_CLASSES=$(kubectl get ingressclass --no-headers 2>/dev/null | wc -l)
    print_success "Found $INGRESS_CLASSES Ingress classes"
    kubectl get ingressclass --no-headers 2>/dev/null | awk '{print "  " $0}'
else
    print_warning "Ingress APIs not available (may need Kubernetes 1.19+)"
fi

# Check 9: StorageClass
print_section "Checking StorageClass"
STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
if [[ $STORAGE_CLASSES -gt 0 ]]; then
    print_success "Found $STORAGE_CLASSES StorageClass"
    kubectl get storageclass --no-headers | awk '{print "  " $0}'
else
    print_warning "No StorageClass found (persistent volumes not available)"
fi

# Check 10: Cert-manager
print_section "Checking Cert-Manager (Optional)"
if kubectl get crd certificates.cert-manager.io &> /dev/null; then
    CERT_MANAGER_NS=$(kubectl get deployment -A | grep cert-manager | head -1 | awk '{print $1}')
    if [[ -n "$CERT_MANAGER_NS" ]]; then
        print_success "Cert-manager is installed in namespace: $CERT_MANAGER_NS"
    fi
else
    print_warning "Cert-manager not found (you can install it later for TLS support)"
fi

# Check 11: DNS
print_section "Checking DNS Resolution"
POD_NAME=$(kubectl run dns-test-$$-$RANDOM --image=alpine -q --rm --restart=Never -- sleep 1 2>/dev/null || echo "")
if [[ -n "$POD_NAME" ]]; then
    kubectl wait --for=condition=Ready pod/dns-test-$$-$RANDOM -n default --timeout=10s 2>/dev/null || true
    print_success "DNS pod creation works"
else
    print_warning "Could not test DNS (insufficient permissions)"
fi

# Check 12: RBAC
print_section "Checking RBAC"
if kubectl api-resources | grep -q "clusterroles"; then
    ROLES=$(kubectl get clusterroles --no-headers 2>/dev/null | wc -l)
    print_success "RBAC is available ($ROLES cluster roles found)"
else
    print_error "RBAC not available"
    FAILURES=$((FAILURES + 1))
fi

# Check 13: Namespace creation
print_section "Checking Namespace Permissions"
TEST_NS="test-money-keeper-$$"
if kubectl create namespace "$TEST_NS" &> /dev/null; then
    kubectl delete namespace "$TEST_NS" &> /dev/null
    print_success "Can create namespaces (required for deployment)"
else
    print_error "Cannot create namespaces (check RBAC permissions)"
    FAILURES=$((FAILURES + 1))
fi

# Check 14: Memory availability
print_section "Checking Memory Requirements"
REQUIRED_MEMORY_MI=1536  # 512 + 256 + overhead
AVAILABLE_MEMORY=$(kubectl top nodes --no-headers 2>/dev/null | awk '{mem+=$6} END {print mem}' || echo "0")

if [[ $AVAILABLE_MEMORY -gt 0 ]]; then
    if [[ $AVAILABLE_MEMORY -gt $REQUIRED_MEMORY_MI ]]; then
        print_success "Available memory ($AVAILABLE_MEMORY Mi) is sufficient"
    else
        print_warning "Available memory ($AVAILABLE_MEMORY Mi) may be insufficient (required: ${REQUIRED_MEMORY_MI} Mi)"
    fi
else
    print_warning "Could not determine available memory"
fi

# Summary
print_section "Validation Summary"
echo ""

if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your cluster is ready for Money Keeper deployment."
    echo ""
    echo "Next steps:"
    echo "  1. Setup GitHub secrets: KUBE_CONFIG_BASE64, DB_* secrets"
    echo "  2. Update helm-charts/money-keeper/values-*.yaml with your environment"
    echo "  3. Run: ./scripts/deploy.sh [environment]"
    exit 0
else
    echo -e "${RED}✗ $FAILURES check(s) failed${NC}"
    echo ""
    echo "Please fix the above issues before deploying."
    exit 1
fi
