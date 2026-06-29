#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

load_deploy_env
mkdir -p "${K8S_GENERATED}"

SERVICE_API_KEY="${SERVICE_API_KEY:-placeholder-update-after-api-key-step}"

log "Gerando manifests em ${K8S_GENERATED}..."

cat >"${K8S_GENERATED}/secrets.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: togglemaster-secrets
  namespace: ${NAMESPACE}
type: Opaque
data:
  AUTH_DATABASE_URL: $(b64 "${AUTH_DATABASE_URL}")
  FLAG_DATABASE_URL: $(b64 "${FLAG_DATABASE_URL}")
  TARGET_DATABASE_URL: $(b64 "${TARGET_DATABASE_URL}")
  MASTER_KEY: $(b64 "${MASTER_KEY}")
  SERVICE_API_KEY: $(b64 "${SERVICE_API_KEY}")
  REDIS_URL: $(b64 "${REDIS_URL}")
EOF

cat >"${K8S_GENERATED}/configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: togglemaster-config
  namespace: ${NAMESPACE}
data:
  AUTH_SERVICE_URL: "http://auth-service:8001"
  FLAG_SERVICE_URL: "http://flag-service:8002"
  TARGETING_SERVICE_URL: "http://targeting-service:8003"
  AWS_REGION: "${AWS_REGION}"
  AWS_SQS_URL: "${AWS_SQS_URL}"
  AWS_DYNAMODB_TABLE: "${AWS_DYNAMODB_TABLE}"
EOF

write_deployment() {
  local name="$1" port="$2" image="$3"
  shift 3
  local env_block="$*"

  cat >"${K8S_GENERATED}/deployment-${name}.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels:
    app: ${name}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:
      containers:
        - name: ${name}
          image: ${image}
          ports:
            - containerPort: ${port}
          env:
            - name: PORT
              value: "${port}"
${env_block}
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health
              port: ${port}
            initialDelaySeconds: 20
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /health
              port: ${port}
            initialDelaySeconds: 10
            periodSeconds: 10
EOF
}

write_deployment auth-service 8001 "$(ecr_image auth-service)" \
'            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: AUTH_DATABASE_URL
            - name: MASTER_KEY
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: MASTER_KEY'

write_deployment flag-service 8002 "$(ecr_image flag-service)" \
'            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: FLAG_DATABASE_URL
            - name: AUTH_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AUTH_SERVICE_URL'

write_deployment targeting-service 8003 "$(ecr_image targeting-service)" \
'            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: TARGET_DATABASE_URL
            - name: AUTH_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AUTH_SERVICE_URL'

write_deployment evaluation-service 8004 "$(ecr_image evaluation-service)" \
'            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: REDIS_URL
            - name: FLAG_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: FLAG_SERVICE_URL
            - name: TARGETING_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: TARGETING_SERVICE_URL
            - name: SERVICE_API_KEY
              valueFrom:
                secretKeyRef:
                  name: togglemaster-secrets
                  key: SERVICE_API_KEY
            - name: AWS_SQS_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AWS_SQS_URL
            - name: AWS_REGION
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AWS_REGION'

write_deployment analytics-service 8005 "$(ecr_image analytics-service)" \
'            - name: AWS_SQS_URL
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AWS_SQS_URL
            - name: AWS_DYNAMODB_TABLE
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AWS_DYNAMODB_TABLE
            - name: AWS_REGION
              valueFrom:
                configMapKeyRef:
                  name: togglemaster-config
                  key: AWS_REGION'

ok "Manifests gerados"
