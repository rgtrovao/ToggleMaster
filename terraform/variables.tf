variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos recursos AWS"
  type        = string
  default     = "togglemaster"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_types" {
  description = "Tipo de instância dos nodes EKS"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_min_size" {
  type    = number
  default = 1
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 4
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "ecr_repository_names" {
  description = "Nomes dos repositórios ECR (microsserviços)"
  type        = list(string)
  default = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]
}

variable "sqs_queue_name" {
  type    = string
  default = "togglemaster-events"
}

variable "dynamodb_table_name" {
  type    = string
  default = "ToggleMasterAnalytics"
}
