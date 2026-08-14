# =============================================================================
#  Interfaz de entrada del módulo. Todo lo que se puede configurar desde
#  fuera vive aquí y solo aquí: quien evalúe si este módulo le sirve lee
#  este archivo y ninguno más.
# =============================================================================

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
  description = "Bloque /24 inicial de cada capa dentro de la VPC. Separarlas de 16 en 16 deja espacio para crecer sin renumerar."
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


# -----------------------------------------------------------------------------
#  Interruptores de coste
# -----------------------------------------------------------------------------
# Los tres recursos caros de esta arquitectura son el NAT Gateway y los
# interface endpoints. Se pueden apagar por separado para que los ejemplos
# y la suite de tests corran sin generar factura. Ver docs/decisions.md.

variable "nat_strategy" {
  description = "none = sin salida a internet desde las subredes privadas (gratis). single = 1 NAT compartido (dev). per_az = 1 NAT por zona (prod, tolera la caída de una zona)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_strategy)
    error_message = "nat_strategy debe ser 'none', 'single' o 'per_az'."
  }
}

variable "enable_ssm_endpoints" {
  description = "Crea los interface endpoints de SSM para administrar instancias sin bastión ni SSH. Cuestan por hora y por zona."
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
