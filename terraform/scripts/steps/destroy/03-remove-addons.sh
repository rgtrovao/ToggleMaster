#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/common.sh"

log "Removendo add-ons do cluster (Ingress + Metrics Server)..."

if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
  helm uninstall ingress-nginx -n ingress-nginx
  ok "Helm release ingress-nginx removido"
else
  warn "Helm release ingress-nginx não encontrado"
fi

if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  kubectl delete namespace ingress-nginx --wait=true --timeout=300s
  ok "Namespace ingress-nginx removido"
fi

kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml \
  --ignore-not-found=true >/dev/null 2>&1 || true

ok "Add-ons removidos"
