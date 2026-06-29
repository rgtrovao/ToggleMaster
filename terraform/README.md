# ToggleMaster — Infraestrutura AWS (Terraform)

Provisiona VPC, EKS, 3× RDS PostgreSQL, ElastiCache Redis, DynamoDB, SQS, ECR e Secrets Manager.

## Pré-requisitos

- Terraform >= 1.5
- AWS CLI autenticado
- Para deploy da aplicação: `kubectl`, `helm`, `docker`, `jq`

## 1. Provisionar infraestrutura

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # opcional
terraform init
terraform plan
terraform apply
```

**Custo estimado:** ~$150–250/mês. Destrua após a entrega:

```bash
terraform destroy
```

## 2. Deploy da aplicação (automático)

Após o `terraform apply` concluir:

```bash
./scripts/deploy-aws.sh
```

O script executa, em ordem:

| Etapa | O que faz |
|-------|-----------|
| `kubeconfig` | `aws eks update-kubeconfig` + aguarda nodes |
| `rds` | Job no EKS aplica `init.sql` nos 3 RDS |
| `ecr` | Build + push das 5 imagens Docker (`linux/amd64` para nodes EKS) |
| `addons` | Metrics Server + Nginx Ingress (Helm) |
| `k8s` | Gera secrets/deployments e `kubectl apply` |
| `apikey` | Cria API key via auth-service |
| `test` | Smoke test via URL do Load Balancer |

### Opções úteis

```bash
# Imagens já publicadas no ECR
./scripts/deploy-aws.sh --skip ecr

# Só reaplicar manifests K8s
./scripts/deploy-aws.sh --step k8s

# Sem confirmação interativa
./scripts/deploy-aws.sh -y
```

### Arquivos gerados (gitignored)

- `terraform/secrets/connection.env` — endpoints e credenciais
- `terraform/secrets/api-key.txt` — API key criada no deploy
- `terraform/secrets/ingress-hostname.txt` — URL do ALB
- `k8s/generated/` — secrets e deployments com imagens ECR

## 3. Verificação manual

```bash
aws eks update-kubeconfig --name togglemaster --region us-east-1
kubectl get pods -n togglemaster
kubectl get hpa -n togglemaster
kubectl get ingress -n togglemaster

# API key (se rodou deploy-aws)
cat terraform/secrets/api-key.txt
```

## Outputs Terraform

```bash
terraform output eks_cluster_name
terraform output ecr_repository_urls
terraform output sqs_queue_url
terraform output -raw master_key   # sensitive
```

## O que o Terraform NÃO faz

- Push de imagens Docker (feito por `deploy-aws.sh --step ecr`)
- Manifests Kubernetes (feito por `deploy-aws.sh --step k8s`)
- Init de schemas RDS (feito por `deploy-aws.sh --step rds`)

O ambiente **local** (`docker compose`) permanece independente.

## 4. Remover deploy da aplicação (sem terraform destroy)

Para derrubar apenas pods, Ingress e add-ons do EKS:

```bash
./scripts/destroy-aws.sh
```

| Etapa | O que faz |
|-------|-----------|
| `kubeconfig` | Conecta kubectl ao cluster |
| `app` | Remove namespace `togglemaster` |
| `addons` | Desinstala Nginx Ingress + Metrics Server |
| `alb` | Aguarda Load Balancer ser removido |
| `clean` | Apaga arquivos locais gerados |

Depois, destrua a infra manualmente:

```bash
terraform destroy
```

Opções:

```bash
./scripts/destroy-aws.sh -y              # sem confirmação
./scripts/destroy-aws.sh --keep-local    # mantém secrets/api-key locais
./scripts/destroy-aws.sh --skip clean    # não apaga arquivos locais
```
