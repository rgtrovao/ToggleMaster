#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log "Configurando kubeconfig para cluster ${CLUSTER_NAME}..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null

if ! kubectl cluster-info >/dev/null 2>&1; then
  die "Sem acesso ao cluster EKS. Verifique credenciais AWS e access entry do seu usuário IAM."
fi

ok "kubectl conectado ao cluster ${CLUSTER_NAME}"
