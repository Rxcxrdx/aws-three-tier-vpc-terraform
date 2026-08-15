output "alb_security_group_id" {
  description = "Security group del balanceador. Asignar al ALB."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group de la capa de aplicación. Asignar a las instancias o tareas."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group de la base de datos. Asignar a RDS o equivalente."
  value       = aws_security_group.db.id
}

output "data_network_acl_id" {
  description = "NACL aplicado a las subredes de datos."
  value       = aws_network_acl.data.id
}
