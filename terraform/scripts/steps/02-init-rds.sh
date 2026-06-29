#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

load_deploy_env

log "Preparando Job de init dos schemas RDS..."

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

kubectl -n "${NAMESPACE}" delete job rds-init --ignore-not-found=true >/dev/null 2>&1 || true

kubectl -n "${NAMESPACE}" create configmap rds-init-sql \
  --from-file=auth-init.sql="${ROOT_DIR}/auth-service/db/init.sql" \
  --from-file=flag-init.sql="${ROOT_DIR}/flag-service/db/init.sql" \
  --from-file=target-init.sql="${ROOT_DIR}/targeting-service/db/init.sql" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: rds-init-credentials
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  AUTH_DATABASE_URL: "${AUTH_DATABASE_URL}"
  FLAG_DATABASE_URL: "${FLAG_DATABASE_URL}"
  TARGET_DATABASE_URL: "${TARGET_DATABASE_URL}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: rds-init
  namespace: ${NAMESPACE}
spec:
  backoffLimit: 3
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: psql
          image: postgres:16-alpine
          command:
            - /bin/sh
            - -ec
            - |
              echo ">>> auth-db schema"
              psql "\${AUTH_DATABASE_URL}" -v ON_ERROR_STOP=1 -f /sql/auth-init.sql
              echo ">>> flag-db schema"
              psql "\${FLAG_DATABASE_URL}" -v ON_ERROR_STOP=1 -f /sql/flag-init.sql
              echo ">>> target-db schema"
              psql "\${TARGET_DATABASE_URL}" -v ON_ERROR_STOP=1 -f /sql/target-init.sql
              echo ">>> RDS init concluído"
          envFrom:
            - secretRef:
                name: rds-init-credentials
          volumeMounts:
            - name: sql
              mountPath: /sql
              readOnly: true
      volumes:
        - name: sql
          configMap:
            name: rds-init-sql
EOF

wait_for_job rds-init
ok "Schemas aplicados nos 3 RDS"
