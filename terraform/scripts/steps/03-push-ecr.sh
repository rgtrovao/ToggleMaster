#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log "Login no ECR..."
local_acct="$(account_id)"
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin \
  "${local_acct}.dkr.ecr.${AWS_REGION}.amazonaws.com"

services=(auth-service flag-service targeting-service evaluation-service analytics-service)

for svc in "${services[@]}"; do
  image="$(ecr_image "${svc}")"
  log "Build ${svc} -> ${image} (platform: ${DOCKER_PLATFORM})"
  docker build --platform "${DOCKER_PLATFORM}" -t "${image}" "${ROOT_DIR}/${svc}"
  log "Push ${image}"
  docker push "${image}"
  ok "${svc} publicado"
done

ok "Todas as imagens enviadas ao ECR"
