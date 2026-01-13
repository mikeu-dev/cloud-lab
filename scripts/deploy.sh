#!/bin/bash
set -e

ACTION=$1
ENV=$2

if [ -z "$ACTION" ]; then
  echo "Usage: ./deploy.sh [apply|rollback] [env]"
  exit 1
fi

echo "🚀 Starting deployment action: $ACTION..."

if [ "$ACTION" == "apply" ]; then
    echo "Applying manifests to cluster..."
    # In real world: kubectl apply -f k8s/overlays/$ENV
    kubectl apply -f k8s/apps/nodejs-app/
    kubectl apply -f k8s/apps/python-app/
    echo "✅ Apply complete."
elif [ "$ACTION" == "rollback" ]; then
    echo "Rolling back..."
    kubectl rollout undo deployment/nodejs-app
    kubectl rollout undo deployment/python-app
    echo "✅ Rollback complete."
else
    echo "Unknown action: $ACTION"
    exit 1
fi
