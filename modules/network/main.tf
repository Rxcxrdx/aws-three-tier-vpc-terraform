# VPC de tres capas replicada en N zonas de disponibilidad. Ver README.md.

# AWS aleatoriza los nombres de zona por cuenta: fijarlos haría impredecible
# el reparto al desplegar en otra.
data "aws_availability_zones" "available" {
  # Excluye zonas en mantenimiento o degradadas.
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Mapa plano de subredes con clave "capa-zona", una por combinación.
  subnets = merge([
    for tier, offset in var.tier_offsets : {
      for idx, az in local.azs :

      "${tier}-${az}" => {
        # El offset separa capas y el índice separa zonas dentro de la capa.
        cidr = cidrsubnet(var.vpc_cidr, 8, offset + idx)
        az   = az
        tier = tier
      }
    }

    # El "..." expande la lista en argumentos; pegado al corchete o falla.
  ]...)
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Prerrequisito de los endpoints de SSM: sin DNS no resuelven sus nombres.
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Los tags propios van al final para que no se puedan sobrescribir.
  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

# for_each y no count: con count la identidad es la posición, y borrar un
# elemento intermedio recrea todos los siguientes.
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.tier == "public"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"

    # Las rutas y los outputs filtran por este tag, no por el nombre.
    Tier = each.value.tier
  })
}
