# Los outputs de un módulo no se ven desde el directorio raíz que lo llama:
# hay que reexponerlos aquí para consultarlos con "terraform output".

output "vpc_id" {
  description = "ID de la VPC de dev."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Subredes públicas. Aquí va el balanceador."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Subredes privadas. Aquí viven las aplicaciones."
  value       = module.network.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Subredes de datos. Aisladas, sin salida a internet."
  value       = module.network.data_subnet_ids
}

output "security_group_ids" {
  description = "Los tres security groups encadenados."
  value = {
    alb = module.security.alb_security_group_id
    app = module.security.app_security_group_id
    db  = module.security.db_security_group_id
  }
}

output "flow_logs_group_name" {
  description = "Log group donde consultar el tráfico de la VPC."
  value       = module.network.flow_logs_group_name
}

# Vacío salvo que se despliegue con enable_ssm_test = true. Es el argumento
# de "aws ssm start-session --target ...".
output "instance_id" {
  description = "ID de la instancia de demostración de SSM, si está activada."
  value       = var.enable_ssm_test ? aws_instance.ssm_test[0].id : null
}
