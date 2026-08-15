# Andamio para las pruebas del módulo de seguridad: una VPC y dos subredes.
#
# No reutiliza modules/network a propósito: ese módulo levanta NAT Gateways y
# endpoints, que no hacen falta para probar security groups.

variable "name" {
  description = "Prefijo para los recursos efímeros de prueba."
  type        = string
  default     = "tftest-sec"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC de prueba. Aislado del rango de los entornos."
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

# Son las que consume el NACL del módulo de seguridad.
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
