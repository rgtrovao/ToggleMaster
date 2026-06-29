#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

STEPS_DIR="$(dirname "$0")"
bash "${STEPS_DIR}/05-generate-k8s.sh"

log "Aplicando manifests Kubernetes..."

kubectl apply -f "${K8S_DIR}/namespace.yaml"
kubectl apply -f "${K8S_GENERATED}/secrets.yaml"
kubectl apply -f "${K8S_GENERATED}/configmap.yaml"
kubectl apply -f "${K8S_DIR}/services.yaml"

for dep in auth-service flag-service targeting-service evaluation-service analytics-service; do
  kubectl apply -f "${K8S_GENERATED}/deployment-${dep}.yaml"
done

kubectl apply -f "${K8S_DIR}/ingress.yaml"
kubectl apply -f "${K8S_DIR}/ingress-health.yaml"
kubectl apply -f "${K8S_DIR}/hpa.yaml"

for dep in auth-service flag-service targeting-service evaluation-service analytics-service; do
  wait_for_deployment "${dep}"
done

ok "Todos os deployments estão rodando"
