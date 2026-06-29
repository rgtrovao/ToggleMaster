#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/common.sh"

log "Removendo aplicação ToggleMaster (namespace ${NAMESPACE})..."

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl delete namespace "${NAMESPACE}" --wait=true --timeout=300s
  ok "Namespace ${NAMESPACE} removido"
else
  warn "Namespace ${NAMESPACE} não encontrado — nada a remover"
fi

# Manifests estáticos aplicados fora do namespace (caso existam)
kubectl delete -f "${K8S_DIR}/hpa.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "${K8S_DIR}/ingress-health.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "${K8S_DIR}/ingress.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "${K8S_DIR}/services.yaml" --ignore-not-found=true >/dev/null 2>&1 || true

ok "Recursos da aplicação removidos"
