module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = []
}

module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
  queue_name   = var.sqs_queue_name
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = var.dynamodb_table_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name     = var.project_name
  repository_names = var.ecr_repository_names
}

module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnets
  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_desired_size   = var.eks_node_desired_size
  node_max_size       = var.eks_node_max_size
  sqs_queue_arn       = module.sqs.queue_arn
  dynamodb_table_arn  = module.dynamodb.table_arn
}

module "rds" {
  source = "./modules/rds"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnets
  allowed_security_group_id = module.eks.node_security_group_id
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name              = var.project_name
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnets
  allowed_security_group_id = module.eks.node_security_group_id
  node_type                 = var.elasticache_node_type
}

module "secrets" {
  source = "./modules/secrets"

  project_name        = var.project_name
  auth_database_url   = module.rds.auth_database_url
  flag_database_url   = module.rds.flag_database_url
  target_database_url = module.rds.target_database_url
}
