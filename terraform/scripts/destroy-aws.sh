#!/usr/bin/env bash
# destroy-aws.sh — Remove o deploy da aplicação ToggleMaster no EKS.
#
# NÃO executa terraform destroy — rode manualmente depois:
#   cd terraform && terraform destroy
#
# Pré-requisitos:
#   - Cluster EKS ainda existente (terraform apply ativo)
#   - aws, kubectl, helm instalados e autenticados
#
# Uso:
#   ./terraform/scripts/destroy-aws.sh
#   ./terraform/scripts/destroy-aws.sh -y
#   ./terraform/scripts/destroy-aws.sh --skip clean

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

STEPS_DIR="${SCRIPT_DIR}/steps/destroy"

SKIP_STEPS=()
ONLY_STEP=""
AUTO_YES=false
KEEP_LOCAL=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Remove do EKS: app, Ingress, Metrics Server e aguarda ALB sumir.
Não destrói infraestrutura Terraform (VPC, RDS, EKS, etc.).

Opções:
  --step STEP     Executa só uma etapa: kubeconfig|app|addons|alb|clean
  --skip STEP     Pula etapa(s), separadas por vírgula (ex: --skip clean)
  --keep-local    Não apaga arquivos em terraform/secrets/ e k8s/generated/
  --region REG    Região AWS (default: us-east-1)
  --cluster NAME  Nome do cluster EKS (default: togglemaster)
  -y              Não pedir confirmação
  -h              Ajuda

Etapas (ordem):
  1. kubeconfig  — aws eks update-kubeconfig
  2. app         — remove namespace togglemaster (pods, ingress, hpa, job rds-init)
  3. addons      — desinstala Nginx Ingress (Helm) + Metrics Server
  4. alb         — aguarda Load Balancer do Ingress ser removido
  5. clean       — apaga arquivos locais gerados pelo deploy

Depois:
  cd terraform && terraform destroy

Exemplo:
  $(basename "$0") -y
  $(basename "$0") --skip clean
EOF
}

ensure_destroy_prerequisites() {
  require_cmd aws kubectl helm
  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS CLI não autenticado."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) ONLY_STEP="$2"; shift 2 ;;
    --skip) IFS=',' read -ra SKIP_STEPS <<< "$2"; shift 2 ;;
    --keep-local) KEEP_LOCAL=true; shift ;;
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

ensure_destroy_prerequisites

if [[ "${AUTO_YES}" != true && -z "${ONLY_STEP}" ]]; then
  echo ""
  echo "Este script vai REMOVER do cluster ${CLUSTER_NAME} (${AWS_REGION}):"
  echo "  - Namespace ${NAMESPACE} (5 microsserviços, Ingress, HPA, Job RDS)"
  echo "  - Nginx Ingress Controller (Helm) + Metrics Server"
  echo "  - Aguardar remoção do Load Balancer"
  if [[ "${KEEP_LOCAL}" != true ]]; then
    echo "  - Arquivos locais em terraform/secrets/ e k8s/generated/"
  fi
  echo ""
  echo "NÃO executa terraform destroy."
  echo ""
  read -r -p "Continuar? [y/N] " ans
  [[ "${ans}" =~ ^[yY] ]] || die "Cancelado pelo usuário"
fi

run_step kubeconfig "${STEPS_DIR}/01-kubeconfig.sh"
run_step app       "${STEPS_DIR}/02-remove-app.sh"
run_step addons    "${STEPS_DIR}/03-remove-addons.sh"
run_step alb       "${STEPS_DIR}/04-wait-alb.sh"

if [[ "${KEEP_LOCAL}" != true ]]; then
  run_step clean "${STEPS_DIR}/05-clean-local.sh"
else
  warn "Mantendo arquivos locais (--keep-local)"
fi

cat <<EOF

============================================================
Deploy removido do EKS.

Próximo passo (manual):
  cd ${TF_DIR}
  terraform destroy
============================================================
EOF

ok "Pipeline destroy-aws concluído"
