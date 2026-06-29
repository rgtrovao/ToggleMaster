#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

hostname=""
if [[ -f "${STATE_DIR}/ingress-hostname.txt" ]]; then
  hostname="$(cat "${STATE_DIR}/ingress-hostname.txt")"
else
  hostname="$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
fi

[[ -n "${hostname}" ]] || die "Ingress LB ainda sem hostname. Aguarde e tente novamente."

BASE="http://${hostname}"
API_KEY=""
if [[ -f "${STATE_DIR}/api-key.txt" ]]; then
  API_KEY="$(cat "${STATE_DIR}/api-key.txt")"
fi

log "Smoke test em ${BASE}"

curl -sf "${BASE}/flags" -H "Authorization: Bearer ${API_KEY}" >/dev/null && ok "flag /flags" || warn "flag /flags falhou"
curl -sf "${BASE}/rules/test-flag" -H "Authorization: Bearer ${API_KEY}" >/dev/null && ok "targeting /rules" || warn "targeting /rules (404 ok se flag não existe)"
curl -sf "${BASE}/evaluate?user_id=u1&flag_name=test" >/dev/null && ok "evaluation /evaluate" || warn "evaluation /evaluate falhou"

cat <<EOF

============================================================
Deploy concluído!

  Ingress URL : ${BASE}
  API Key     : ${API_KEY:-(rode step apikey)}
  Postman     : use Authorization: Bearer <api_key>

  kubectl get pods -n ${NAMESPACE}
  kubectl get hpa -n ${NAMESPACE}
============================================================
EOF
