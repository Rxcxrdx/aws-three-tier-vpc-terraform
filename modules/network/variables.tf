variable "name" {
  description = "Prefijo para nombrar y etiquetar todos los recursos. Ej: dev, prod."
  type        = string
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC en notación CIDR."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr debe ser un CIDR IPv4 válido, ej: 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Cantidad de zonas de disponibilidad a usar. Mínimo 2 para alta disponibilidad."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count debe estar entre 2 y 4. Menos de 2 rompe la alta disponibilidad."
  }
}

variable "tier_offsets" {
  description = "Bloque /24 inicial de cada capa. Separarlas de 16 en 16 deja crecer hasta 16 zonas por capa sin renumerar."
  type        = map(number)

  default = {
    public  = 0
    private = 16
    data    = 32
  }

  validation {
    condition     = alltrue([for o in values(var.tier_offsets) : o % 16 == 0])
    error_message = "Cada offset debe ser múltiplo de 16 para reservar 16 bloques /24 por capa."
  }
}

variable "nat_strategy" {
  description = "none = sin salida desde las subredes privadas. single = 1 NAT compartido. per_az = 1 NAT por zona, tolera la caída de una zona."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_strategy)
    error_message = "nat_strategy debe ser 'none', 'single' o 'per_az'."
  }
}

variable "enable_ssm_endpoints" {
  description = "Crea los interface endpoints de SSM para administrar instancias sin bastión ni SSH."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Registra en CloudWatch cada conexión aceptada o rechazada de la VPC."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Días que CloudWatch retiene los flow logs antes de borrarlos."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags adicionales para todos los recursos del módulo."
  type        = map(string)
  default     = {}
}
