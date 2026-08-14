# Los outputs del módulo NO se ven solos en la terminal de envs/dev.
# Hay que reexponerlos aquí para poder consultarlos con "terraform output"
# desde este directorio.

output "vpc_id" {
  description = "ID de la VPC de dev."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Subredes públicas de dev."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Subredes privadas de dev."
  value       = module.network.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Subredes de datos de dev."
  value       = module.network.data_subnet_ids
}

output "instance_id" {
  value = aws_instance.ssm_test.id
}