# =============================================================================
#  modules/network/outputs.tf
#
#  El contrato público del módulo. Todo lo que está dentro del módulo es
#  privado; solo lo que se declara aquí es visible desde afuera.
#
#  Es el "return" de una función. Y como todo contrato: mientras menos
#  prometas, más libre eres para refactorizar por dentro.
# =============================================================================


# -----------------------------------------------------------------------------
#  La VPC
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID de la VPC. Lo necesita cualquier recurso que viva dentro de ella."
  value       = aws_vpc.this.id
}

# Exponemos el CIDR aparte porque se usa muchísimo en reglas de firewall:
# "permitir tráfico desde cualquier lugar dentro de la VPC" se escribe
# referenciando este valor, no copiando "10.0.0.0/16" a mano.
output "vpc_cidr" {
  description = "Rango de direcciones de la VPC. Útil para reglas de seguridad."
  value       = aws_vpc.this.cidr_block
}


# -----------------------------------------------------------------------------
#  IDs de subredes por capa
# -----------------------------------------------------------------------------
# aws_subnet.this es un MAPA de 6 subredes (por el for_each). Quien consume
# el módulo no las quiere todas juntas: el balanceador necesita las públicas,
# la app las privadas, la base de datos las de datos.
#
# Así que filtramos el mapa por capa.
#
# Anatomía de la expresión:
#   [ for k, v in aws_subnet.this : v.id if v.tags.Tier == "public" ]
#     ↑                              ↑         ↑
#     [ ] = produce LISTA            |         filtro: solo si cumple
#                                    qué devolver de cada elemento
#
# El "if" al final de un for es un filtro. Se lee: "por cada subred, dame
# su id, pero solo si su tag Tier es public".
#
# Nota: filtramos por el tag y no por la llave del mapa. La llave es
# "public-us-east-1a" y podríamos usar startswith(), pero el tag es un dato
# explícito que pusimos a propósito. Filtrar por el nombre de la llave sería
# depender de una convención de texto; filtrar por el tag es depender de un
# dato. Lo segundo es más robusto.

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


# -----------------------------------------------------------------------------
#  Mapa de subredes privadas por zona
# -----------------------------------------------------------------------------
# ⚠️ Este es el output que resuelve un problema que las listas de arriba NO
# resuelven.
#
# private_subnet_ids devuelve ["subnet-abc", "subnet-def"], pero NO dice
# cuál está en us-east-1a y cuál en us-east-1b. Se perdió la zona.
#
# Y eso importa: en prod habrá un NAT Gateway por zona, y cada subred
# privada debe enrutar al NAT de SU PROPIA zona. Si la subred de la zona A
# enruta al NAT de la zona B, funciona... hasta que la zona B se caiga y
# tumbe también la zona A. Justo lo contrario de la alta disponibilidad
# que estás pagando.
#
# Con la AZ como llave del mapa, se puede emparejar cada subred con su NAT:
#   { "us-east-1a" = "subnet-abc", "us-east-1b" = "subnet-def" }
#
# Aquí el "for" produce un MAPA (llaves { } y flecha =>) en vez de una lista.
#
# Moraleja de diseño: una lista plana pierde el contexto. Cuando lo que
# consume necesita saber CUÁL ES CUÁL, se expone un mapa con llave
# significativa, no una lista.
output "private_subnet_ids_by_az" {
  description = "Subredes privadas indexadas por zona. Necesario para enrutar cada zona a su propio NAT."
  value       = { for k, v in aws_subnet.this : v.availability_zone => v.id if v.tags.Tier == "private" }
}


# -----------------------------------------------------------------------------
#  Las zonas en uso
# -----------------------------------------------------------------------------
# Quien consuma el módulo puede necesitar iterar sobre las mismas zonas que
# usamos aquí, sin volver a consultar AWS ni arriesgarse a que le den otras.
output "azs" {
  description = "Zonas de disponibilidad en uso por esta VPC."
  value       = local.azs
}

output "flow_logs_group_name" {
  description = "Nombre del log group. Uso: consultas de Logs Insights."
  value       = aws_cloudwatch_log_group.flow_logs.name
}