#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de deploy AWS.

set -euo pipefail

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_LIB_DIR}/.." && pwd)"
TF_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${TF_DIR}/.." && pwd)"
K8S_DIR="${ROOT_DIR}/k8s"
K8S_GENERATED="${K8S_DIR}/generated"
STATE_DIR="${TF_DIR}/secrets"

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-togglemaster}"
PROJECT_NAME="${PROJECT_NAME:-togglemaster}"
NAMESPACE="${NAMESPACE:-togglemaster}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
ok()   { printf '\033[1;32m[%s] OK\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[%s] WARN\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31m[%s] ERRO\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: ${cmd}"
  done
}

ensure_prerequisites() {
  require_cmd aws kubectl helm docker terraform jq
  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS CLI não autenticado. Configure credenciais primeiro."
  [[ -d "${TF_DIR}" ]] || die "Diretório terraform não encontrado: ${TF_DIR}"
  [[ -f "${TF_DIR}/main.tf" ]] || die "Execute a partir de um repo com terraform/main.tf"
}

tf_output() {
  local name="$1"
  terraform -chdir="${TF_DIR}" output -raw "${name}" 2>/dev/null
}

tf_output_json() {
  terraform -chdir="${TF_DIR}" output -json 2>/dev/null
}

sm_secret() {
  local id="$1"
  aws secretsmanager get-secret-value \
    --secret-id "${id}" \
    --region "${AWS_REGION}" \
    --query SecretString \
    --output text
}

account_id() {
  aws sts get-caller-identity --query Account --output text
}

ecr_image() {
  local service="$1"
  local acct
  acct="$(account_id)"
  echo "${acct}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}/${service}:${IMAGE_TAG}"
}

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

wait_for_nodes() {
  log "Aguardando nodes EKS ficarem Ready..."
  local i
  for i in $(seq 1 60); do
    local ready total
    ready="$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)"
    total="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${ready}" -ge 1 && "${ready}" == "${total}" && "${total}" -gt 0 ]]; then
      ok "Nodes prontos (${ready}/${total})"
      return 0
    fi
    sleep 10
  done
  die "Timeout aguardando nodes EKS"
}

wait_for_deployment() {
  local name="$1"
  log "Aguardando deployment/${name}..."
  kubectl rollout status "deployment/${name}" -n "${NAMESPACE}" --timeout=300s
}

wait_for_job() {
  local name="$1"
  log "Aguardando job/${name}..."
  kubectl wait --for=condition=complete "job/${name}" -n "${NAMESPACE}" --timeout=300s
}

load_deploy_env() {
  mkdir -p "${STATE_DIR}" "${K8S_GENERATED}"

  export AUTH_DATABASE_URL
  export FLAG_DATABASE_URL
  export TARGET_DATABASE_URL
  export MASTER_KEY
  export REDIS_URL
  export AWS_SQS_URL
  export AWS_DYNAMODB_TABLE
  export AWS_REGION="${AWS_REGION}"

  AUTH_DATABASE_URL="$(sm_secret "${PROJECT_NAME}/auth-db")"
  FLAG_DATABASE_URL="$(sm_secret "${PROJECT_NAME}/flag-db")"
  TARGET_DATABASE_URL="$(sm_secret "${PROJECT_NAME}/target-db")"
  MASTER_KEY="$(sm_secret "${PROJECT_NAME}/master-key")"
  REDIS_URL="$(tf_output redis_url)"
  AWS_SQS_URL="$(tf_output sqs_queue_url)"
  AWS_DYNAMODB_TABLE="$(tf_output dynamodb_table_name)"

  [[ -n "${AUTH_DATABASE_URL}" ]] || die "Secret ${PROJECT_NAME}/auth-db não encontrado. Terraform apply concluiu?"
  [[ -n "${REDIS_URL}" ]] || die "Output redis_url não encontrado. Rode terraform apply."
}

save_connection_env() {
  load_deploy_env
  local file="${STATE_DIR}/connection.env"
  umask 077
  cat >"${file}" <<EOF
# Gerado por deploy-aws.sh — NÃO COMMITAR
AWS_REGION=${AWS_REGION}
REDIS_URL=${REDIS_URL}
AWS_SQS_URL=${AWS_SQS_URL}
AWS_DYNAMODB_TABLE=${AWS_DYNAMODB_TABLE}
MASTER_KEY=${MASTER_KEY}
AUTH_DATABASE_URL=${AUTH_DATABASE_URL}
FLAG_DATABASE_URL=${FLAG_DATABASE_URL}
TARGET_DATABASE_URL=${TARGET_DATABASE_URL}
EOF
  ok "Credenciais salvas em ${file}"
}
