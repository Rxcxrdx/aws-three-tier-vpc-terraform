output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Rango de direcciones de la VPC. Útil para reglas de seguridad."
  value       = aws_vpc.this.cidr_block
}

# El filtro va contra el tag Tier, que es un dato, y no contra el prefijo de
# la clave, que es una convención de texto.

output "public_subnet_ids" {
  description = "IDs de las subredes públicas. Aquí va el balanceador."
  value       = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "public"]
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas. Aquí viven las aplicaciones."
  value       = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "private"]
}

output "data_subnet_ids" {
  description = "IDs de las subredes de datos. Aisladas, sin salida a internet."
  value       = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "data"]
}

# Una lista plana pierde la zona, y hace falta para emparejar cada subred con
# el NAT de la suya: cruzarlas anula la alta disponibilidad.
output "private_subnet_ids_by_az" {
  description = "Subredes privadas indexadas por zona. Necesario para enrutar cada zona a su propio NAT."
  value       = { for k, v in aws_subnet.this : v.availability_zone => v.id if v.tags.Tier == "private" }
}

output "azs" {
  description = "Zonas de disponibilidad en uso por esta VPC."
  value       = local.azs
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateway creados. Vacío si nat_strategy = none."
  value       = [for k, v in aws_nat_gateway.this : v.id]
}

output "flow_logs_group_name" {
  description = "Nombre del log group de flow logs, o null si están desactivados."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
