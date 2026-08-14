# =============================================================================
#  Interfaz de entrada del módulo de seguridad.
# =============================================================================

variable "vpc_id" {
  description = "ID de la VPC donde crear los security groups y el NACL."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC. El NACL de la capa de datos lo usa para permitir solo tráfico interno."
  type        = string
}

variable "name" {
  description = "Prefijo para nombrar los recursos. Ej: dev, prod."
  type        = string
}

variable "data_subnet_ids" {
  description = "IDs de las subredes de datos a las que se asocia el NACL restrictivo."
  type        = list(string)
}

variable "app_port" {
  description = "Puerto en el que la capa de aplicación escucha al balanceador."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Puerto en el que la base de datos escucha a la aplicación. 5432 = PostgreSQL."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags adicionales para todos los recursos del módulo."
  type        = map(string)
  default     = {}
}
