output "tfstate_bucket_name" {
  description = "Nombre del bucket de state. Cópialo al backend.tf de cada ambiente."
  value       = aws_s3_bucket.tfstate.id
}