output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Certificado CA do cluster EKS"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "URLs dos repositórios ECR (map servico -> URL)"
  value       = module.ecr.repository_urls
}

output "rds_auth_endpoint" {
  description = "Endpoint RDS auth-db"
  value       = module.rds.auth_endpoint
}

output "rds_flag_endpoint" {
  description = "Endpoint RDS flag-db"
  value       = module.rds.flag_endpoint
}

output "rds_target_endpoint" {
  description = "Endpoint RDS target-db"
  value       = module.rds.target_endpoint
}

output "redis_endpoint" {
  description = "Endpoint ElastiCache Redis"
  value       = module.elasticache.redis_endpoint
}

output "redis_url" {
  description = "URL de conexão Redis"
  value       = module.elasticache.redis_url
}

output "sqs_queue_url" {
  description = "URL da fila SQS"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS"
  value       = module.sqs.queue_arn
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB"
  value       = module.dynamodb.table_arn
}

output "secrets_manager_arns" {
  description = "ARNs dos secrets no Secrets Manager"
  value       = module.secrets.secret_arns
}

output "master_key" {
  description = "Master key gerada para auth-service (sensitive)"
  value       = module.secrets.master_key
  sensitive   = true
}
