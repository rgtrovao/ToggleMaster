variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_id" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

locals {
  databases = {
    auth = {
      identifier = "${var.project_name}-auth-db"
      db_name    = "authdb"
      username   = "auth"
    }
    flag = {
      identifier = "${var.project_name}-flag-db"
      db_name    = "flagdb"
      username   = "flaguser" # "flag" é palavra reservada no RDS PostgreSQL
    }
    target = {
      identifier = "${var.project_name}-target-db"
      db_name    = "targetdb"
      username   = "target"
    }
  }
}

resource "random_password" "db" {
  for_each = local.databases

  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "PostgreSQL acesso dos nodes EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  for_each = local.databases

  identifier     = each.value.identifier
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  db_name               = each.value.db_name
  username              = each.value.username
  password              = random_password.db[each.key].result
  port                  = 5432
  publicly_accessible   = false
  multi_az              = false
  skip_final_snapshot   = true
  deletion_protection   = false
  apply_immediately     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 1
}
