#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../lib/common.sh"

log "Limpando arquivos locais gerados pelo deploy..."

rm -f "${STATE_DIR}/connection.env" \
      "${STATE_DIR}/api-key.txt" \
      "${STATE_DIR}/ingress-hostname.txt" 2>/dev/null || true

if [[ -d "${K8S_GENERATED}" ]]; then
  find "${K8S_GENERATED}" -type f ! -name '.gitignore' -delete 2>/dev/null || true
fi

ok "Arquivos locais removidos (terraform/secrets/, k8s/generated/)"
