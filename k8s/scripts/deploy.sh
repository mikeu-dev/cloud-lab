#!/bin/bash

# CloudLab Kubernetes Deployment Script
# This script automates the deployment of CloudLab to Kubernetes

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

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_info "Prerequisites check passed!"
}

build_images() {
    print_info "Building Docker images..."
    
    cd apps/demo-apps/nodejs-app
    docker build -t cloudlab-nodejs-app:latest .
    print_info "Built cloudlab-nodejs-app:latest"
    
    cd ../python-app
    docker build -t cloudlab-python-app:latest .
    print_info "Built cloudlab-python-app:latest"
    
    cd ../../..
}

load_images_minikube() {
    print_info "Loading images to Minikube..."
    
    if command -v minikube &> /dev/null; then
        minikube image load cloudlab-nodejs-app:latest
        minikube image load cloudlab-python-app:latest
        print_info "Images loaded to Minikube"
    else
        print_warn "Minikube not found, skipping image load"
    fi
}

generate_ssl_certs() {
    print_info "Generating SSL certificates..."
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /tmp/cloudlab-tls.key \
        -out /tmp/cloudlab-tls.crt \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=CloudLab/OU=Dev/CN=cloudlab.local" \
        2>/dev/null
    
    # Encode to base64
    TLS_CRT=$(cat /tmp/cloudlab-tls.crt | base64 -w 0)
    TLS_KEY=$(cat /tmp/cloudlab-tls.key | base64 -w 0)
    
    # Update secret file
    sed -i "s|tls.crt:.*|tls.crt: $TLS_CRT|" k8s/base/secrets/ssl-certs.yaml
    sed -i "s|tls.key:.*|tls.key: $TLS_KEY|" k8s/base/secrets/ssl-certs.yaml
    
    # Cleanup
    rm -f /tmp/cloudlab-tls.key /tmp/cloudlab-tls.crt
    
    print_info "SSL certificates generated and updated"
}

deploy_kubernetes() {
    print_info "Deploying to Kubernetes..."
    
    # Apply kustomization
    kubectl apply -k k8s/
    
    print_info "Kubernetes resources created"
}

wait_for_rollout() {
    print_info "Waiting for deployments to be ready..."
    
    # Wait for apps
    kubectl rollout status deployment/nodejs-app -n cloudlab-apps --timeout=5m
    kubectl rollout status deployment/python-app -n cloudlab-apps --timeout=5m
    
    # Wait for monitoring
    kubectl rollout status deployment/grafana -n cloudlab-monitoring --timeout=5m
    kubectl rollout status statefulset/prometheus -n cloudlab-monitoring --timeout=5m
    
    print_info "All deployments are ready!"
}

show_status() {
    print_info "Deployment Status:"
    echo ""
    
    print_info "Pods in cloudlab-apps:"
    kubectl get pods -n cloudlab-apps
    echo ""
    
    print_info "Pods in cloudlab-monitoring:"
    kubectl get pods -n cloudlab-monitoring
    echo ""
    
    print_info "Services in cloudlab-apps:"
    kubectl get svc -n cloudlab-apps
    echo ""
    
    print_info "Services in cloudlab-monitoring:"
    kubectl get svc -n cloudlab-monitoring
    echo ""
    
    print_info "Ingress:"
    kubectl get ingress -A
    echo ""
}

show_access_info() {
    print_info "Access Information:"
    echo ""
    echo "Port Forwarding Commands:"
    echo "  kubectl port-forward svc/nodejs-app 3001:3001 -n cloudlab-apps"
    echo "  kubectl port-forward svc/python-app 5000:5000 -n cloudlab-apps"
    echo "  kubectl port-forward svc/grafana 3000:3000 -n cloudlab-monitoring"
    echo "  kubectl port-forward svc/prometheus 9090:9090 -n cloudlab-monitoring"
    echo ""
    
    if command -v minikube &> /dev/null; then
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "N/A")
        echo "Minikube IP: $MINIKUBE_IP"
        echo ""
        echo "Add to /etc/hosts:"
        echo "  $MINIKUBE_IP cloudlab.local grafana.cloudlab.local prometheus.cloudlab.local"
        echo ""
        echo "Then access:"
        echo "  https://cloudlab.local"
        echo "  https://grafana.cloudlab.local (admin/admin123)"
        echo "  https://prometheus.cloudlab.local"
    fi
}

# Main execution
main() {
    print_info "Starting CloudLab Kubernetes Deployment"
    echo ""
    
    check_prerequisites
    
    # Ask for confirmation
    read -p "Do you want to build Docker images? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_images
        load_images_minikube
    fi
    
    # Generate SSL certs
    read -p "Do you want to generate new SSL certificates? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_ssl_certs
    fi
    
    # Deploy
    read -p "Do you want to deploy to Kubernetes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_kubernetes
        wait_for_rollout
        show_status
        show_access_info
    fi
    
    print_info "Deployment script completed!"
}

# Run main
main
