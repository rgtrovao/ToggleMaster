#!/usr/bin/env bash
# deploy-aws.sh — Automatiza o deploy da aplicação ToggleMaster na AWS após terraform apply.
#
# Pré-requisitos:
#   - terraform apply concluído
#   - aws, kubectl, helm, docker, jq instalados
#   - credenciais AWS configuradas
#
# Uso:
#   ./terraform/scripts/deploy-aws.sh              # todas as etapas
#   ./terraform/scripts/deploy-aws.sh --step ecr   # só uma etapa
#   ./terraform/scripts/deploy-aws.sh --skip ecr   # pular build/push
#
# Etapas: kubeconfig | rds | ecr | addons | k8s | apikey | test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

STEPS_DIR="${SCRIPT_DIR}/steps"
ALL_STEPS=(kubeconfig rds ecr addons k8s apikey test)

SKIP_STEPS=()
ONLY_STEP=""
AUTO_YES=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Opções:
  --step STEP     Executa só uma etapa: kubeconfig|rds|ecr|addons|k8s|apikey|test
  --skip STEP     Pula etapa(s), separadas por vírgula (ex: --skip ecr)
  --region REG    Região AWS (default: us-east-1)
  --cluster NAME  Nome do cluster EKS (default: togglemaster)
  -y              Não pedir confirmação
  -h              Ajuda

Etapas (ordem):
  1. kubeconfig  — aws eks update-kubeconfig + aguardar nodes
  2. rds         — Job K8s aplica init.sql nos 3 RDS
  3. ecr         — docker build + push das 5 imagens
  4. addons      — Metrics Server + Nginx Ingress (Helm)
  5. k8s         — gera secrets/deployments e kubectl apply
  6. apikey      — cria API key e reinicia evaluation-service
  7. test        — smoke test via Ingress LB

Exemplo:
  $(basename "$0") --skip ecr     # imagens já no ECR
  $(basename "$0") --step k8s     # só reaplicar manifests
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) ONLY_STEP="$2"; shift 2 ;;
    --skip) IFS=',' read -ra SKIP_STEPS <<< "$2"; shift 2 ;;
    --region) AWS_REGION="$2"; export AWS_REGION; shift 2 ;;
    --cluster) CLUSTER_NAME="$2"; export CLUSTER_NAME; shift 2 ;;
    -y) AUTO_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

should_run() {
  local step="$1"
  local s
  for s in "${SKIP_STEPS[@]:-}"; do
    [[ "${s}" == "${step}" ]] && return 1
  done
  if [[ -n "${ONLY_STEP}" && "${ONLY_STEP}" != "${step}" ]]; then
    return 1
  fi
  return 0
}

run_step() {
  local step="$1" script="$2"
  should_run "${step}" || { warn "Pulando etapa: ${step}"; return 0; }
  log "========== Etapa: ${step} =========="
  bash "${script}"
}

ensure_prerequisites

if [[ "${AUTO_YES}" != true && -z "${ONLY_STEP}" ]]; then
  echo ""
  echo "Este script vai:"
  echo "  - Configurar kubectl no cluster ${CLUSTER_NAME} (${AWS_REGION})"
  echo "  - Inicializar schemas RDS via Job no EKS"
  echo "  - Build/push 5 imagens Docker para ECR"
  echo "  - Instalar Metrics Server + Nginx Ingress"
  echo "  - Deploy dos 5 microsserviços no Kubernetes"
  echo "  - Criar API key e rodar smoke test"
  echo ""
  read -r -p "Continuar? [y/N] " ans
  [[ "${ans}" =~ ^[yY] ]] || die "Cancelado pelo usuário"
fi

save_connection_env

run_step kubeconfig "${STEPS_DIR}/01-kubeconfig.sh"
run_step rds       "${STEPS_DIR}/02-init-rds.sh"
run_step ecr       "${STEPS_DIR}/03-push-ecr.sh"
run_step addons    "${STEPS_DIR}/04-install-addons.sh"
run_step k8s       "${STEPS_DIR}/06-apply-k8s.sh"
run_step apikey    "${STEPS_DIR}/07-create-api-key.sh"
run_step test      "${STEPS_DIR}/08-smoke-test.sh"

ok "Pipeline deploy-aws concluído"
