#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log "Instalando Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

log "Aguardando Metrics Server..."
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s || \
  warn "Metrics Server ainda inicializando — HPA pode demorar a funcionar"

log "Instalando Nginx Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update ingress-nginx

if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
  warn "ingress-nginx já instalado — pulando"
else
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer \
    --wait --timeout 10m
fi

log "Aguardando Load Balancer do Ingress..."
for i in $(seq 1 60); do
  hostname="$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -n "${hostname}" ]]; then
    ok "Ingress LB: http://${hostname}"
    echo "${hostname}" > "${STATE_DIR}/ingress-hostname.txt"
    exit 0
  fi
  sleep 15
done

warn "Load Balancer ainda provisionando. Verifique depois com: kubectl get svc -n ingress-nginx"
