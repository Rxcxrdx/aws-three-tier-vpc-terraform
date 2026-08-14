# =============================================================================
#  El contrato público del módulo. Todo lo demás es privado: mientras menos
#  se prometa aquí, más libertad hay para refactorizar por dentro sin
#  romper a quien lo consume.
# =============================================================================

output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

# Se expone aparte porque las reglas de firewall lo necesitan constantemente:
# "permitir solo tráfico interno" se escribe referenciando esto, no copiando
# el CIDR a mano en cada regla.
output "vpc_cidr" {
  description = "Rango de direcciones de la VPC. Útil para reglas de seguridad."
  value       = aws_vpc.this.cidr_block
}


# Las subredes se entregan separadas por capa porque nadie las quiere todas
# juntas: el balanceador necesita las públicas, la aplicación las privadas y
# la base de datos las de datos.
#
# El filtro va contra el tag Tier y no contra el prefijo de la clave. La
# clave es un texto que alguien puede reformatear; el tag es un dato puesto
# a propósito para esto.

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


# Una lista plana de IDs pierde la zona de cada subred, y esa información
# hace falta para emparejar cada subred privada con el NAT de SU zona. Si la
# subred de la zona A enruta al NAT de la zona B, la caída de B se lleva
# también a A: exactamente lo contrario de la alta disponibilidad que se
# está pagando. Cuando el consumidor necesita saber cuál es cuál, se expone
# un mapa con clave significativa, no una lista.
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
  description = "Nombre del log group de flow logs, o null si están desactivados. Punto de partida para consultas en Logs Insights."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
