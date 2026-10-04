#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo " Starting deployment"

echo "Checking required tools..."

command -v kubectl >/dev/null || {
    echo "ERROR: kubectl is not installed"
    exit 1
}

command -v helm >/dev/null || {
    echo "ERROR: helm is not installed"
    exit 1
}

echo "kubectl: OK"
echo "helm:    OK"

echo
echo "Creating namespaces..."

kubectl apply -f k8s/namespaces.yaml

echo
echo "Installing/upgrading Envoy Gateway..."

helm upgrade --install eg \
    oci://docker.io/envoyproxy/gateway-helm \
    --version v1.9.2 \
    -n envoy-gateway-system \
    --create-namespace

echo
echo "Waiting for Envoy Gateway..."

kubectl rollout status deployment/envoy-gateway \
    -n envoy-gateway-system \
    --timeout=180s

echo
echo "Applying EnvoyProxy configuration..."

kubectl apply -f k8s/gateway/envoyproxy.yaml

echo
echo "Applying Gateway API resources..."

kubectl apply -f k8s/app/gatewayclass.yaml
kubectl apply -f k8s/app/gateway.yaml
kubectl apply -f k8s/app/httproute.yaml

echo
echo "Deploying application..."

kubectl apply -f k8s/app/deployment.yaml
kubectl apply -f k8s/app/service.yaml

echo
echo "Installing/upgrading Prometheus..."

helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts 2>/dev/null || true

helm repo update

helm upgrade --install prometheus \
    prometheus-community/prometheus \
    -n monitoring \
    --create-namespace \
    -f k8s/monitoring/prometheus-values.yaml

echo
echo "Deploying Fluentd..."

kubectl apply -f k8s/logging/fluentd-config.yaml
kubectl apply -f k8s/logging/fluentd-daemonset.yaml

echo
echo "Waiting for application..."

kubectl rollout status deployment/nginx \
    -n app \
    --timeout=180s

echo
echo "Waiting for Fluentd..."

kubectl rollout status daemonset/fluentd \
    -n logging \
    --timeout=180s

echo
echo "Waiting for Prometheus..."

kubectl rollout status deployment/prometheus-server \
    -n monitoring \
    --timeout=180s

echo
echo " Deployment completed successfully!"

echo
echo "Run verification:"
echo "./scripts/verify.sh"