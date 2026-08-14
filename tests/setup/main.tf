# =============================================================================
#  tests/setup — andamio para las pruebas del módulo de seguridad.
#
#  El módulo de seguridad solo se puede verificar de verdad sobre recursos
#  reales: "el SG de app referencia al SG del ALB" es un ID que no existe
#  hasta el apply, y el SG default hay que adoptarlo de una VPC que exista.
#
#  Por eso NO se reutiliza ./modules/network aquí: ese módulo levanta NAT
#  Gateways, EIPs y VPC Endpoints, que cuestan dinero y tardan minutos.
#  Esto es lo mínimo indispensable: una VPC y dos subredes. Todo gratis.
# =============================================================================

variable "name" {
  description = "Prefijo para los recursos efímeros de prueba."
  type        = string
  default     = "tftest-sec"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC de prueba. Aislado del rango que usan los entornos."
  type        = string
  default     = "10.99.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = { Name = var.name }
}

# Dos subredes de datos: son las que consume el NACL del módulo de seguridad.
resource "aws_subnet" "data" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 32 + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-data-${count.index}"
    Tier = "data"
  }
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}
