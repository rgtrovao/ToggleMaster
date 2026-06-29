#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/common.sh"

log "Aguardando Load Balancers do Kubernetes serem removidos..."

for i in $(seq 1 40); do
  count="$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
    --query 'length(LoadBalancers[?contains(LoadBalancerName, `k8s`) || contains(LoadBalancerName, `ingress`)])' \
    --output text 2>/dev/null || echo "0")"

  if [[ "${count}" == "0" || "${count}" == "None" ]]; then
    ok "Nenhum Load Balancer Kubernetes pendente"
    exit 0
  fi

  log "Ainda existem ${count} LB(s) — aguardando (${i}/40)..."
  sleep 15
done

warn "Load Balancer(s) ainda visível(is) após timeout."
warn "Aguarde alguns minutos antes de rodar 'terraform destroy'."
