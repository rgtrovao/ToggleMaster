variable "project_name" {
  type = string
}

variable "auth_database_url" {
  type      = string
  sensitive = true
}

variable "flag_database_url" {
  type      = string
  sensitive = true
}

variable "target_database_url" {
  type      = string
  sensitive = true
}

resource "random_password" "master_key" {
  length  = 32
  special = false
}

locals {
  secrets = {
    auth-db = var.auth_database_url
    flag-db = var.flag_database_url
    target-db = var.target_database_url
    master-key = "master_key_${random_password.master_key.result}"
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name        = "${var.project_name}/${each.key}"
  description = "ToggleMaster secret: ${each.key}"
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = each.value
}
