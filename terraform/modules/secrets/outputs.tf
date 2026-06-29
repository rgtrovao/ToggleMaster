output "secret_arns" {
  value = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "master_key" {
  value     = "master_key_${random_password.master_key.result}"
  sensitive = true
}
