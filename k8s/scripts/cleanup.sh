#!/bin/bash

# CloudLab Kubernetes Cleanup Script
# This script removes all CloudLab resources from Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup_resources() {
    print_info "Cleaning up CloudLab resources..."
    
    # Delete using kustomization
    if [ -f "k8s/kustomization.yaml" ]; then
        print_info "Deleting resources via kustomization..."
        kubectl delete -k k8s/ --ignore-not-found=true
    fi
    
    # Delete namespaces (this will cascade delete all resources)
    print_info "Deleting namespaces..."
    kubectl delete namespace cloudlab-apps --ignore-not-found=true
    kubectl delete namespace cloudlab-monitoring --ignore-not-found=true
    
    print_info "Cleanup completed!"
}

show_remaining() {
    print_info "Checking for remaining resources..."
    
    # Check namespaces
    if kubectl get namespace cloudlab-apps &> /dev/null; then
        print_warn "Namespace cloudlab-apps still exists"
    fi
    
    if kubectl get namespace cloudlab-monitoring &> /dev/null; then
        print_warn "Namespace cloudlab-monitoring still exists"
    fi
    
    # Check PVs
    PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace | contains("cloudlab")) | .metadata.name' 2>/dev/null || echo "")
    if [ -n "$PVS" ]; then
        print_warn "Found PersistentVolumes that may need manual cleanup:"
        echo "$PVS"
    fi
}

# Main execution
main() {
    print_warn "This will delete ALL CloudLab resources from Kubernetes!"
    print_warn "This action cannot be undone."
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no) " -r
    echo
    
    if [[ $REPLY == "yes" ]]; then
        cleanup_resources
        
        # Wait a bit for resources to be deleted
        print_info "Waiting for resources to be deleted..."
        sleep 5
        
        show_remaining
        print_info "Cleanup script completed!"
    else
        print_info "Cleanup cancelled."
    fi
}

# Run main
main
