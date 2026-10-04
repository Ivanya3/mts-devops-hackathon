#!/usr/bin/env bash

set -euo pipefail
echo " Kubernetes"
kubectl get nodes
echo
echo " Application"


kubectl get deployment,service,pods -n app

echo
echo " Gateway API"

kubectl get gatewayclass
kubectl get gateway -n app
kubectl get httproute -n app

echo
echo "Gateway conditions:"

kubectl get gateway nginx-gateway \
    -n app \
    -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'

echo
echo " External HTTP"

NODE_IP="$(kubectl get nodes \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"

NODE_PORT="$(kubectl get svc \
    -n envoy-gateway-system \
    -o jsonpath='{range .items[?(@.spec.type=="NodePort")].spec.ports[*]}{.nodePort}{"\n"}{end}' \
    | head -n 1)"

echo "Node IP:   $NODE_IP"
echo "Node Port: $NODE_PORT"

echo
echo "Testing application..."

curl -fsS "http://${NODE_IP}:${NODE_PORT}/" >/dev/null

echo "OK: application is accessible through Gateway API"

echo
echo " Prometheus"

PROM_PORT=19090

kubectl port-forward \
    -n monitoring \
    svc/prometheus-server \
    ${PROM_PORT}:80 \
    >/tmp/prometheus-port-forward.log 2>&1 &

PF_PID=$!

cleanup() {
    kill "$PF_PID" 2>/dev/null || true
}

trap cleanup EXIT

sleep 3

echo "Prometheus version:"

curl -fsS \
    "http://127.0.0.1:${PROM_PORT}/api/v1/status/buildinfo"

echo
echo
echo 'PromQL: up{job="envoy-gateway"}'

curl -fsS \
    --get \
    --data-urlencode 'query=up{job="envoy-gateway"}' \
    "http://127.0.0.1:${PROM_PORT}/api/v1/query"

echo
echo " Fluentd"

kubectl get daemonset -n logging
kubectl get pods -n logging

echo
echo "Recent Fluentd logs:"

kubectl logs \
    -n logging \
    daemonset/fluentd \
    --tail=10

echo
echo " Verification completed successfully!"