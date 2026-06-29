#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log "Configurando kubeconfig para cluster ${CLUSTER_NAME}..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null

if ! kubectl cluster-info >/dev/null 2>&1; then
  warn "kubectl sem acesso ao cluster — tentando criar access entry para o usuário IAM atual..."
  principal="$(aws sts get-caller-identity --query Arn --output text)"
  if [[ "${principal}" == *":user/"* ]]; then
    aws eks create-access-entry \
      --cluster-name "${CLUSTER_NAME}" \
      --region "${AWS_REGION}" \
      --principal-arn "${principal}" \
      --type STANDARD 2>/dev/null || true
    aws eks associate-access-policy \
      --cluster-name "${CLUSTER_NAME}" \
      --region "${AWS_REGION}" \
      --principal-arn "${principal}" \
      --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
      --access-scope type=cluster 2>/dev/null || true
    sleep 5
  fi
  kubectl cluster-info >/dev/null 2>&1 || die "Sem acesso ao EKS. Rode: terraform apply (enable_cluster_creator_admin_permissions) ou crie access entry manualmente para ${principal:-seu IAM user}"
fi

wait_for_nodes
ok "kubectl configurado"
