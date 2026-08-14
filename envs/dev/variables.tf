variable "region" {
  description = "Región de AWS donde desplegar el entorno."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Responsable del entorno. Aparece como tag en cada recurso, para saber a quién preguntar antes de borrar algo."
  type        = string
  default     = "unassigned"
}

variable "enable_ssm_test" {
  description = "Despliega una instancia EC2 en la subred de datos para demostrar que Session Manager conecta sin SSH ni bastión. Apagada por defecto: es una demostración, no parte de la infraestructura, y cuesta dinero mientras esté encendida."
  type        = bool
  default     = false
}
