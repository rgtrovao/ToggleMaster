output "auth_endpoint" {
  value = aws_db_instance.this["auth"].address
}

output "flag_endpoint" {
  value = aws_db_instance.this["flag"].address
}

output "target_endpoint" {
  value = aws_db_instance.this["target"].address
}

output "auth_database_url" {
  value     = "postgres://${aws_db_instance.this["auth"].username}:${random_password.db["auth"].result}@${aws_db_instance.this["auth"].address}:5432/${aws_db_instance.this["auth"].db_name}"
  sensitive = true
}

output "flag_database_url" {
  value     = "postgres://${aws_db_instance.this["flag"].username}:${random_password.db["flag"].result}@${aws_db_instance.this["flag"].address}:5432/${aws_db_instance.this["flag"].db_name}"
  sensitive = true
}

output "target_database_url" {
  value     = "postgres://${aws_db_instance.this["target"].username}:${random_password.db["target"].result}@${aws_db_instance.this["target"].address}:5432/${aws_db_instance.this["target"].db_name}"
  sensitive = true
}

output "auth_username" {
  value = aws_db_instance.this["auth"].username
}

output "flag_username" {
  value = aws_db_instance.this["flag"].username
}

output "target_username" {
  value = aws_db_instance.this["target"].username
}

output "auth_password" {
  value     = random_password.db["auth"].result
  sensitive = true
}

output "flag_password" {
  value     = random_password.db["flag"].result
  sensitive = true
}

output "target_password" {
  value     = random_password.db["target"].result
  sensitive = true
}
