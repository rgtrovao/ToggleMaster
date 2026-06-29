#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

load_deploy_env

log "Criando API key via auth-service..."

# Port-forward local para auth-service (não depende do Ingress estar pronto)
kubectl port-forward -n "${NAMESPACE}" svc/auth-service 18001:8001 >/tmp/tm-pf-auth.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT

for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:18001/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

response="$(curl -sf -X POST http://127.0.0.1:18001/admin/keys \
  -H "Authorization: Bearer ${MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"name":"aws-deploy-key"}')"

API_KEY="$(echo "${response}" | jq -r '.key')"
[[ -n "${API_KEY}" && "${API_KEY}" != "null" ]] || die "Falha ao criar API key: ${response}"

ok "API key criada (salva em ${STATE_DIR}/api-key.txt)"
umask 077
printf '%s\n' "${API_KEY}" > "${STATE_DIR}/api-key.txt"

log "Atualizando secret SERVICE_API_KEY e reiniciando evaluation-service..."

kubectl -n "${NAMESPACE}" patch secret togglemaster-secrets --type merge -p \
  "$(jq -n --arg k "$(b64 "${API_KEY}")" '{data: {SERVICE_API_KEY: $k}}')"

kubectl -n "${NAMESPACE}" rollout restart deployment/evaluation-service
wait_for_deployment evaluation-service

ok "evaluation-service configurado com a nova API key"
